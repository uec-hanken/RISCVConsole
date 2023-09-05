#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <float.h>
#include "libmfcc.h"

#include <sndfile.h>
#include "fix_fft.h"

#define	BLOCK_SIZE 4096

static void
print_usage (char *progname)
{	printf ("\nUsage : %s <input file> <output file> <fft file>\n", progname) ;
	puts ("\n"
		"    Where the output file will contain a line for each frame\n"
		"    and a column for each channel.\n"
		) ;

} /* print_usage */

static int
convert_to_text (SNDFILE * infile, FILE * outfile, int channels)
{	int *buf ;
	sf_count_t frames ;
	int k, m, readcount ;
	sf_seek(infile, 0, SEEK_SET  );

	buf = (int *)malloc (BLOCK_SIZE * sizeof (int)) ;
	if (buf == NULL)
	{	printf ("Error : Out of memory.\n\n") ;
		return 1 ;
		} ;

	frames = BLOCK_SIZE / channels ;

	while ((readcount = (int) sf_readf_int (infile, buf, frames)) > 0)
	{	for (k = 0 ; k < readcount ; k++)
		{	for (m = 0 ; m < channels ; m++)
				fprintf (outfile, " %d", buf [k * channels + m]);
			fprintf (outfile, "\n") ;
			} ;
		} ;

	free (buf) ;

	return 0 ;
} /* convert_to_text */

#ifdef __cplusplus
extern "C" {
#endif

void cdft(int, int, double *, int *, double *);

#ifdef __cplusplus
}
#endif

static int
get_fft_fftd_mfcc (SNDFILE * infile, FILE * outfile, FILE* outdfile, FILE* outmfccfile, int channels, long int frames, int samplerate)
{	int *buf ;
	short *fft ;
	sf_seek(infile, 0, SEEK_SET  );
	buf = (int *)malloc (frames * channels * sizeof (int)) ;
	if (buf == NULL)
	{	printf ("Error : Out of memory.\n\n") ;
		return 1 ;
		} ;

    // Determinate the number of samples in powers of 2
    int m = 0;
    long int aframes = frames;
    while(aframes > 0) {
        aframes >>= 1;
        m++;
    }

    // We need to read the exact number of frames (frames is the same as samples)
    long int readframes;
    aframes = BLOCK_SIZE / channels;
    int* bufp = buf;
	int* tbuf = (int *)malloc (BLOCK_SIZE * sizeof (int)) ;
    while((readframes = sf_readf_int (infile, tbuf, aframes)) > 0) {
        memcpy(bufp, tbuf, readframes * sizeof (int));
        bufp += readframes;
    }
	free (tbuf) ;


    // Allocate the memory for the fft, which is 2 times N, which is 2**m
    long int siz = 1<<(m+1); // Which is the same as (2**m)*2
    fft = (short *)malloc (siz * sizeof (short)) ;
	if (fft == NULL)
	{	printf ("Error : Out of memory.\n\n") ;
		return 1 ;
		} ;
    memset(fft, 0, siz * sizeof (short));
	// Now, convert the value to short.
	// For 32-bit, Is just dividing by 65535 (or 2^16)
	for (int k = 0 ; k < frames ; k++)
    {
        // The channel is the 1st one
        fft[k] = (short)(buf[k * channels/* + m*/] >> 16);
        } ;

    // First, calculate n
    int n = siz / 2;
    // Call the fixed fft
    fix_fft(fft, fft+n, m, 0);
    //fix_fftr(fft, m+1, 0);

    // Allocate the memory for the fft, which is 2 times N, which is 2**m
    double* fftd = (double *)malloc (siz * sizeof (double)) ;
	if (fftd == NULL)
	{	printf ("Error : Out of memory.\n\n") ;
		return 1 ;
		} ;
	for (int k = 0 ; k < siz; k++) {
        fftd[k] = 0.0;
	}
	// Now, convert the value to short.
	// For 32-bit, Is just dividing by 32368 to be clamped into [-1.0, 1.0]
	for (int k = 0 ; k < frames; k++)
    {
        // The channel is the 1st one
        fftd[k*2] = ((double)(buf[k * channels/* + m*/] >> 16) / 32768.0);
        //fftd[k*2+1], which is the imaginary part, is zero
        } ;

    // Invoke the fft double version
    // Now, a way to calculate the sqrt(n) is just iterating util i*i surpass (or equals) n
    int sqrtn = 0;
    for(; sqrtn*sqrtn < n; sqrtn++);
    sqrtn += 2 - 1; // We need to quit 1, and add 2
    // Allocate here the temporal arrays this fft needs
    int* ip = (int *)malloc (sqrtn * sizeof (int));
    double* w = (double *)malloc (n / 2 * sizeof (double));
    // Finally, call this wonderful function
    cdft(m, 1, fftd, ip, w);

    // Save the FFT
    double* realfftn = (double *)malloc (n * sizeof (double)); // We will transfer the real part of the fft here
    fprintf (outfile, "# FFT result\n") ;
    fprintf (outfile, "# REAL IMAG\n") ;
    for(int k = 0; k < n; k++) {
        //fprintf (outfile, "%hd, %hd\n", fft[k*2], fft[k*2+1]) ;
        double real = realfftn[k] = (double)fft[k] / 32768.0;
        double imag = (double)fft[n+k] / 32768.0;
        fprintf (outfile, "%g, %g -- %hd, %hd\n", real, imag, fft[k], fft[n+k]) ;
    }

    // Save the FFT double
    fprintf (outdfile, "# FFT result\n") ;
    fprintf (outdfile, "# REAL IMAG\n") ;
    for(int k = 0; k < n; k++) {
        fprintf (outdfile, "%g, %g\n", fftd[k*2], fftd[k*2+1]) ;
    }

    // Invoke the mfcc. Get the first 13 or so
#define NUM_MFCC 13
    double mfcc[NUM_MFCC];
    for(int coeff = 0; coeff < 13; coeff++)
	{
	     mfcc[coeff] = GetCoefficient(realfftn, samplerate, 48, 128, coeff);
	}

    // Save the MFCC
    fprintf (outmfccfile, "# MFCC result\n") ;
    for(int k = 0; k < NUM_MFCC; k++) {
        fprintf (outmfccfile, "%d %g\n", k, mfcc[k]) ;
    }

	free (buf) ;
	free (fft) ;
	free (fftd) ;
	free (ip) ;
	free (w) ;

	return 0 ;
} /* convert_to_text */

int
main (int argc, char * argv [])
{	char 		*progname, *infilename, *outfilename, *outfftfilename, *outfftdfilename, *outmfccfilename ;
	SNDFILE		*infile = NULL ;
	FILE		*outfile = NULL ;
	FILE		*outfftfile = NULL ;
	FILE		*outfftdfile = NULL ;
	FILE		*outmfccfile = NULL ;
	SF_INFO		sfinfo ;
	int 	ret = 1 ;

	progname = strrchr (argv [0], '/') ;
	progname = progname ? progname + 1 : argv [0] ;

	switch (argc)
	{
		case 6 :
			break ;
		default:
			print_usage (progname) ;
			goto cleanup ;
		} ;

	infilename = argv [1] ;
	outfilename = argv [2] ;
	outfftfilename = argv [3] ;
	outfftdfilename = argv [4] ;
	outmfccfilename = argv [5] ;

	if (strcmp (infilename, outfilename) == 0)
	{	printf ("Error : Input and output filenames are the same.\n\n") ;
		print_usage (progname) ;
		goto cleanup ;
		} ;

	if (infilename [0] == '-')
	{	printf ("Error : Input filename (%s) looks like an option.\n\n", infilename) ;
		print_usage (progname) ;
		goto cleanup ;
		} ;

	if (outfilename [0] == '-')
	{	printf ("Error : Output filename (%s) looks like an option.\n\n", outfilename) ;
		print_usage (progname) ;
		goto cleanup ;
		} ;

	memset (&sfinfo, 0, sizeof (sfinfo)) ;

	if ((infile = sf_open (infilename, SFM_READ, &sfinfo)) == NULL)
	{	printf ("Not able to open input file %s.\n", infilename) ;
		puts (sf_strerror (NULL)) ;
		goto cleanup ;
		} ;

	/* Open the output file. */
	if ((outfile = fopen (outfilename, "w")) == NULL)
	{	printf ("Not able to open output file %s : %s\n", outfilename, sf_strerror (NULL)) ;
		goto cleanup ;
		} ;

	/* Open the output file. */
	if ((outfftfile = fopen (outfftfilename, "w")) == NULL)
	{	printf ("Not able to open output file %s : %s\n", outfftfilename, sf_strerror (NULL)) ;
		goto cleanup ;
		} ;

	/* Open the output file. */
	if ((outfftdfile = fopen (outfftdfilename, "w")) == NULL)
	{	printf ("Not able to open output file %s : %s\n", outfftdfilename, sf_strerror (NULL)) ;
		goto cleanup ;
		} ;

	/* Open the output mfcc file. */
	if ((outmfccfile = fopen (outmfccfilename, "w")) == NULL)
	{	printf ("Not able to open output file %s : %s\n", outmfccfilename, sf_strerror (NULL)) ;
		goto cleanup ;
		} ;

	fprintf (outfile, "# Converted from file %s.\n", infilename) ;
	fprintf (outfile, "# Channels %d, Sample rate %d, Format %x, Frames %ld\n", sfinfo.channels, sfinfo.samplerate, sfinfo.format, sfinfo.frames) ;

	ret = convert_to_text (infile, outfile, sfinfo.channels) ;
	ret = get_fft_fftd_mfcc (infile, outfftfile, outfftdfile, outmfccfile, sfinfo.channels, sfinfo.frames, sfinfo.samplerate) ;

cleanup :

	sf_close (infile) ;
	if (outfile != NULL)
		fclose (outfile) ;

	return ret ;
} /* main */
