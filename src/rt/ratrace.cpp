#ifndef lint
static const char	RCSid[] = "$Id: ratrace.cpp,v 2.1 2023/02/08 17:41:48 greg Exp $";
#endif
/*
 *  C++ module for individual ray tracing.
 */

/*
 *  Input is in the form:
 *
 *	xorg	yorg	zorg	xdir	ydir	zdir
 *
 *  The direction need not be normalized.  Output is flexible.
 *  If the direction vector is (0,0,0), then the output is flushed.
 *  All values default to ascii representation of real
 *  numbers.  Binary representations can be selected
 *  with '-ff' for float or '-fd' for double.  By default,
 *  radiance is computed.  The '-i' or '-I' options indicate that
 *  irradiance values are desired.
 */

#include "copyright.h"

#include  "RtraceSimulManager.h"
#include  "platform.h"
#include  "otypes.h"
#include  "otspecial.h"
#include  "source.h"
#include  "resolu.h"

extern int  inform;			/* input format */
extern int  outform;			/* output format */

extern char  *tralist[];		/* list of modifers to trace (or no) */
extern int  traincl;			/* include == 1, exclude == 0 */

extern int  hresolu;			/* horizontal resolution */
extern int  vresolu;			/* vertical resolution */

extern int  castonly;			/* only doing ray-casting? */

#ifndef  MAXTSET
#define	 MAXTSET	8191		/* maximum number in trace set */
#endif
OBJECT	traset[MAXTSET+1]={0};		/* trace include/exclude set */

					// global simulation manager
extern RtraceSimulManager	myRTmanager;

static FILE  *inpfp = NULL;		/* input stream pointer */

static FVECT	*inp_queue = NULL;	/* ray input queue if flushing */
static int	inp_qpos = 0;		/* next ray to return */
static int	inp_qend = 0;		/* number of rays in this work group */

typedef void putf_t(RREAL *v, int n);
static putf_t puta, putd, putf, putrgbe;

typedef void oputf_t(RAY *r);
static oputf_t  oputo, oputd, oputv, oputV, oputl, oputL, oputc, oputp,
		oputr, oputR, oputx, oputX, oputn, oputN, oputs,
		oputw, oputW, oputm, oputM, oputtilde;

extern void tranotify(OBJECT obj);
static void tabin(RAY *r);
static RayReportCall ourtrace;
static RayReportCall printvals;

static oputf_t *ray_out[32], *every_out[32];
static putf_t *putreal;

void
quit(			/* quit program */
	int  code
)
{
	int	ec = myRTmanager.Cleanup();

	if (ec) code = ec;

	exit(code);
}

const char *
formstr(				/* return format identifier */
	int  f
)
{
	switch (f) {
	case 'a': return("ascii");
	case 'f': return("float");
	case 'd': return("double");
	case 'c': return(COLRFMT);
	}
	return("unknown");
}

static bool
getvec(			/* get a vector from fp */
	FVECT  vec,
	int  fmt,
	FILE  *fp
)
{
	static char	buf[32];
	float *		vf = (float *)buf;
	double *	vd = (double *)buf;
	int		i;

	switch (fmt) {
	case 'a':					/* ascii */
		for (i = 0; i < 3; i++) {
			if (fgetword(buf, sizeof(buf), fp) == NULL ||
					!isflt(buf))
				return false;
			vec[i] = atof(buf);
		}
		break;
#ifdef SMLFLT
	case 'f':					/* binary float */
		if (getbinary(vec, sizeof(RREAL), 3, fp) != 3)
			return false;
		break;
	case 'd':					/* binary double */
		if (getbinary(vd, sizeof(double), 3, fp) != 3)
			return false;
		VCOPY(vec, vd);
		break;
#else
	case 'f':					/* binary float */
		if (getbinary(vf, sizeof(float), 3, fp) != 3)
			return false;
		VCOPY(vec, vf);
		break;
	case 'd':					/* binary double */
		if (getbinary(vec, sizeof(RREAL), 3, fp) != 3)
			return false;
		break;
#endif
	default:
		error(CONSISTENCY, "botched input format");
	}
	return true;
}

// read ray list from inpfp
static int
getrays(FVECT org_dir[], int n)
{
	int	nread = 0;

	while (n-- > 0) {
		if (!getvec(org_dir[0], inform, inpfp) ||
				!getvec(org_dir[1], inform, inpfp))
			break;
		++nread;
		if (IsZeroVec(org_dir[1]))
			break;
		org_dir += 2;
	}
	return nread;
}

void
rtrace(				/* trace rays from stdin or file */
	char  *fname,
	int  nproc
)
{
	RNUMBER		vcount = (hresolu > 1) ? (RNUMBER)hresolu*vresolu
					      : (RNUMBER)vresolu;
	const int	flushIntvl = (!vresolu | (hresolu <= 1)) * hresolu;
	FVECT *		ivbuf = (FVECT *)malloc(2*sizeof(FVECT) *
						(flushIntvl + !flushIntvl));
	if (ivbuf == NULL)
		error(SYSTEM, "cannot allocate input vector buffer");
					/* set up input */
	if (fname == NULL)
		inpfp = stdin;
	else if ((inpfp = fopen(fname, "r")) == NULL) {
		sprintf(errmsg, "cannot open input file \"%s\"", fname);
		error(SYSTEM, errmsg);
	}
#ifdef getc_unlocked
	flockfile(inpfp);		/* avoid lock/unlock overhead */
#endif
	if (inform != 'a')
		SET_FILE_BINARY(inpfp);
					/* set up output */
	if (castonly || every_out[0] != NULL)
		nproc = 1;		/* don't bother multiprocessing */
	else if (nproc <= 0)		// need to get default for system?
		nproc = myRTmanager.SetThreadCount();
	if (ray_out[0])
		myRTmanager.SetCookedCall(printvals);
	if (every_out[0])
		myRTmanager.SetTraceCall(ourtrace);
	if ((flushIntvl > 0) & (nproc > flushIntvl)) {
		error(WARNING, "reducing number of processes to match flush interval");
		nproc = flushIntvl;
	}
	nproc = myRTmanager.SetThreadCount(nproc);
	myRTmanager.rtFlags |= RTdoFIFO;
	if (hresolu > 0) {		// print resolution string if appropriate
		if (vresolu > 0)
			fprtresolu(hresolu, vresolu, stdout);
		else
			fflush(stdout);
	}
	int	n;			/* process input rays */
	bool	pending = false;
	while ((n = getrays(ivbuf, flushIntvl + !flushIntvl)) > 0) {
		if ((vcount > 0) & (n > vcount)) {
			error(WARNING, "extra ray(s) past end of input");
			n = vcount;
		}			// put ray(s) into queue
		if (myRTmanager.EnqueueBundle(ivbuf, n) < 0)
			error(USER, "ray queuing failure");
		pending |= (n > 1);	// time to flush output?
		bool	atZero = IsZeroVec(ivbuf[2*n-1]);
		if (pending & (atZero | (n == flushIntvl))) {
			if (!myRTmanager.FlushQueue())
				error(USER, "ray flush error");
			fflush(stdout);
			pending = false;
		} else
			pending |= !atZero;
		if (ferror(stdout))
			error(SYSTEM, "write error");
		if (vcount && !(vcount -= n))		/* check for end */
			break;
	}
	if (vcount)
		error(WARNING, feof(inpfp) ? "unexpected EOF on input" :
				"input read error");
	if (fflush(stdout) < 0)
		error(SYSTEM, "write error");
	if (fname != NULL) {
		fclose(inpfp);
		inpfp = NULL;
	}
	free(ivbuf);
}

int
setrtoutput(const char *outvals)	/* set up output tables, return #comp */
{
	const char  *vs = outvals;
	oputf_t **table = ray_out;
	int  ncomp = 0;

	if (!*vs)
		error(USER, "empty output specification");

	switch (outform) {	/* make sure (*putreal)() calls someone! */
	case 'a': putreal = puta; break;
	case 'f': putreal = putf; break;
	case 'd': putreal = putd; break;
	case 'c':
		if (outvals[1] || !strchr("vrx", outvals[0]))
			error(USER, "color format only with -ov, -or, -ox");
		putreal = putrgbe; break;
	default:
		error(CONSISTENCY, "botched output format");
	}
	castonly = 1;			/* sets castonly as side-effect */
	do
		switch (*vs) {
		case 'T':				/* trace sources */
			myRTmanager.rtFlags |= RTtraceSources;
			/* fall through */
		case 't':				/* trace */
			if (!vs[1]) break;
			*table = NULL;
			table = every_out;
			castonly = 0;
			break;
		case 'o':				/* origin */
			*table++ = oputo;
			ncomp += 3;
			break;
		case 'd':				/* direction */
			*table++ = oputd;
			ncomp += 3;
			break;
		case 'r':				/* reflected contrib. */
			*table++ = oputr;
			ncomp += 3;
			castonly = 0;
			break;
		case 'R':				/* reflected distance */
			*table++ = oputR;
			ncomp++;
			castonly = 0;
			break;
		case 'x':				/* xmit contrib. */
			*table++ = oputx;
			ncomp += 3;
			castonly = 0;
			break;
		case 'X':				/* xmit distance */
			*table++ = oputX;
			ncomp++;
			castonly = 0;
			break;
		case 'v':				/* value */
			*table++ = oputv;
			ncomp += 3;
			castonly = 0;
			break;
		case 'V':				/* contribution */
			*table++ = oputV;
			ncomp += 3;
			castonly = 0;
			if (ambounce > 0 && (ambacc > FTINY || ambssamp > 0))
				error(WARNING,
					"-otV accuracy depends on -aa 0 -as 0");
			break;
		case 'l':				/* effective distance */
			*table++ = oputl;
			ncomp++;
			castonly = 0;
			break;
		case 'c':				/* local coordinates */
			*table++ = oputc;
			ncomp += 2;
			break;
		case 'L':				/* single ray length */
			*table++ = oputL;
			ncomp++;
			break;
		case 'p':				/* point */
			*table++ = oputp;
			ncomp += 3;
			break;
		case 'n':				/* perturbed normal */
			*table++ = oputn;
			ncomp += 3;
			castonly = 0;
			break;
		case 'N':				/* unperturbed normal */
			*table++ = oputN;
			ncomp += 3;
			break;
		case 's':				/* surface */
			*table++ = oputs;
			ncomp++;
			break;
		case 'w':				/* weight */
			*table++ = oputw;
			ncomp++;
			break;
		case 'W':				/* coefficient */
			*table++ = oputW;
			ncomp += 3;
			castonly = 0;
			if (ambounce > 0 && (ambacc > FTINY) | (ambssamp > 0))
				error(WARNING,
					"-otW accuracy depends on -aa 0 -as 0");
			break;
		case 'm':				/* modifier */
			*table++ = oputm;
			ncomp++;
			break;
		case 'M':				/* material */
			*table++ = oputM;
			ncomp++;
			break;
		case '~':				/* tilde */
			*table++ = oputtilde;
			break;
		default:
			sprintf(errmsg, "unrecognized output option '%c'", *vs);
			error(USER, errmsg);
		}
	while (*++vs);

	*table = NULL;
	if (*every_out != NULL)
		ncomp = 0;
							/* compatibility */
	if ((do_irrad | (myRTmanager.rtFlags & RTimmIrrad)) && castonly)
		error(USER, "-I+ and -i+ options require some value output");
	for (table = ray_out; *table != NULL; table++) {
		if ((*table == oputV) | (*table == oputW))
			error(WARNING, "-oVW options require trace mode");
		if ((do_irrad | (myRTmanager.rtFlags & RTimmIrrad)) &&
				(*table == oputr) | (*table == oputR) |
				(*table == oputx) | (*table == oputX))
			error(WARNING, "-orRxX options incompatible with -I+ and -i+");
	}
	return(ncomp);
}

static void
printvals(			/* print requested ray values */
	RAY  *r, void *cd
)
{
	oputf_t **tp;

	if (ray_out[0] == NULL)
		return;
#ifdef getc_unlocked
	flockfile(stdout);
#endif
	for (tp = ray_out; *tp != NULL; tp++)
		(**tp)(r);
	if (outform == 'a')
		putchar('\n');
#ifdef getc_unlocked
	funlockfile(stdout);
#endif
}

void
tranotify(			/* record new modifier */
	OBJECT	obj
)
{
	static int  hitlimit = 0;
	OBJREC	 *o = objptr(obj);
	char  **tralp;

	if (obj == OVOID) {		/* starting over */
		traset[0] = 0;
		hitlimit = 0;
		return;
	}
	if (hitlimit || !ismodifier(o->otype))
		return;
	for (tralp = tralist; *tralp != NULL; tralp++)
		if (!strcmp(o->oname, *tralp)) {
			if (traset[0] >= MAXTSET) {
				error(WARNING, "too many modifiers in trace list");
				hitlimit++;
				return;		/* should this be fatal? */
			}
			insertelem(traset, obj);
			return;
		}
}

static void
ourtrace(				/* print ray values */
	RAY  *r, void *cd
)
{
	oputf_t **tp;

	if (every_out[0] == NULL)
		return;
	if (r->ro == NULL) {
		if (traincl == 1)
			return;
	} else if (traincl != -1 && traincl != inset(traset, r->ro->omod))
		return;
#ifdef getc_unlocked
	flockfile(stdout);
#endif
	tabin(r);
	for (tp = every_out; *tp != NULL; tp++)
		(**tp)(r);
	if (outform == 'a')
		putchar('\n');
#ifdef getc_unlocked
	funlockfile(stdout);
#endif
}

static void
tabin(				/* tab in appropriate amount */
	RAY  *r
)
{
	const RAY  *rp;

	for (rp = r->parent; rp != NULL; rp = rp->parent)
		putchar('\t');
}

static void
oputo(				/* print origin */
	RAY  *r
)
{
	(*putreal)(r->rorg, 3);
}

static void
oputd(				/* print direction */
	RAY  *r
)
{
	(*putreal)(r->rdir, 3);
}

static void
oputr(				/* print mirrored contribution */
	RAY  *r
)
{
	RREAL	cval[3];

	cval[0] = colval(r->mcol,RED);
	cval[1] = colval(r->mcol,GRN);
	cval[2] = colval(r->mcol,BLU);
	(*putreal)(cval, 3);
}

static void
oputR(				/* print mirrored distance */
	RAY  *r
)
{
	(*putreal)(&r->rmt, 1);
}

static void
oputx(				/* print unmirrored contribution */
	RAY  *r
)
{
	RREAL	cval[3];

	cval[0] = colval(r->rcol,RED) - colval(r->mcol,RED);
	cval[1] = colval(r->rcol,GRN) - colval(r->mcol,GRN);
	cval[2] = colval(r->rcol,BLU) - colval(r->mcol,BLU);
	(*putreal)(cval, 3);
}

static void
oputX(				/* print unmirrored distance */
	RAY  *r
)
{
	(*putreal)(&r->rxt, 1);
}

static void
oputv(				/* print value */
	RAY  *r
)
{
	RREAL	cval[3];

	cval[0] = colval(r->rcol,RED);
	cval[1] = colval(r->rcol,GRN);
	cval[2] = colval(r->rcol,BLU);
	(*putreal)(cval, 3);
}

static void
oputV(				/* print value contribution */
	RAY *r
)
{
	RREAL	contr[3];

	raycontrib(contr, r, PRIMARY);
	multcolor(contr, r->rcol);
	(*putreal)(contr, 3);
}

static void
oputl(				/* print effective distance */
	RAY  *r
)
{
	RREAL	d = raydistance(r);

	(*putreal)(&d, 1);
}

static void
oputL(				/* print single ray length */
	RAY  *r
)
{
	(*putreal)(&r->rot, 1);
}

static void
oputc(				/* print local coordinates */
	RAY  *r
)
{
	(*putreal)(r->uv, 2);
}

static RREAL	vdummy[3] = {0.0, 0.0, 0.0};

static void
oputp(				/* print intersection point */
	RAY  *r
)
{
	(*putreal)(r->rop, 3);	/* set to ray origin if distant or no hit */
}

static void
oputN(				/* print unperturbed normal */
	RAY  *r
)
{
	if (r->ro == NULL) {	/* zero vector if clipped or no hit */
		(*putreal)(vdummy, 3);
		return;
	}
	if (r->rflips & 1) {	/* undo any flippin' flips */
		FVECT	unrm;
		unrm[0] = -r->ron[0];
		unrm[1] = -r->ron[1];
		unrm[2] = -r->ron[2];
		(*putreal)(unrm, 3);
	} else
		(*putreal)(r->ron, 3);
}

static void
oputn(				/* print perturbed normal */
	RAY  *r
)
{
	FVECT  pnorm;

	if (r->ro == NULL) {	/* clipped or no hit */
		(*putreal)(vdummy, 3);
		return;
	}
	raynormal(pnorm, r);
	(*putreal)(pnorm, 3);
}

static void
oputs(				/* print name */
	RAY  *r
)
{
	if (r->ro != NULL)
		fputs(r->ro->oname, stdout);
	else
		putchar('*');
	putchar('\t');
}

static void
oputw(				/* print weight */
	RAY  *r
)
{
	RREAL	rwt = r->rweight;
	
	(*putreal)(&rwt, 1);
}

static void
oputW(				/* print coefficient */
	RAY  *r
)
{
	RREAL	contr[3];
				/* shadow ray not on source? */
	if (r->rsrc >= 0 && source[r->rsrc].so != r->ro)
		setcolor(contr, 0.0, 0.0, 0.0);
	else
		raycontrib(contr, r, PRIMARY);

	(*putreal)(contr, 3);
}

static void
oputm(				/* print modifier */
	RAY  *r
)
{
	if (r->ro != NULL)
		if (r->ro->omod != OVOID)
			fputs(objptr(r->ro->omod)->oname, stdout);
		else
			fputs(VOIDID, stdout);
	else
		putchar('*');
	putchar('\t');
}

static void
oputM(				/* print material */
	RAY  *r
)
{
	OBJREC	*mat;

	if (r->ro != NULL) {
		if ((mat = findmaterial(r->ro)) != NULL)
			fputs(mat->oname, stdout);
		else
			fputs(VOIDID, stdout);
	} else
		putchar('*');
	putchar('\t');
}

static void
oputtilde(			/* output tilde (spacer) */
	RAY  *r
)
{
	fputs("~\t", stdout);
}

static void
puta(				/* print ascii value(s) */
	RREAL *v, int n
)
{
	if (n == 3) {
		printf("%e\t%e\t%e\t", v[0], v[1], v[2]);
		return;
	}
	while (n--)
		printf("%e\t", *v++);
}

static void
putd(RREAL *v, int n)		/* output binary double(s) */
{
#ifdef	SMLFLT
	double	da[3];
	int	i;

	if (n > 3)
		error(INTERNAL, "code error in putd()");
	for (i = n; i--; )
		da[i] = v[i];
	putbinary(da, sizeof(double), n, stdout);
#else
	putbinary(v, sizeof(RREAL), n, stdout);
#endif
}

static void
putf(RREAL *v, int n)		/* output binary float(s) */
{
#ifndef	SMLFLT
	float	fa[3];
	int	i;

	if (n > 3)
		error(INTERNAL, "code error in putf()");
	for (i = n; i--; )
		fa[i] = v[i];
	putbinary(fa, sizeof(float), n, stdout);
#else
	putbinary(v, sizeof(RREAL), n, stdout);
#endif
}

static void
putrgbe(RREAL *v, int n)	/* output RGBE color */
{
	COLR  cout;

	if (n != 3)
		error(INTERNAL, "putrgbe() not called with 3 components");
	setcolr(cout, v[0], v[1], v[2]);
	putbinary(cout, sizeof(cout), 1, stdout);
}