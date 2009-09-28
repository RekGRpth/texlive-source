eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
  if 0;
use strict;

# $Id$
# (Copyright lines below.)
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer. 
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution. 
# 3. The name of the author may not be used to endorse or promote
#    products derived from this software without specific prior written
#    permission. 
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR [AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# 
# ----------------------------------------------------------------
# 
# This is a script to transform an EPS file such that:
#   a) it is guaranteed to start at the 0,0 coordinate.
#   b) it sets a page size exactly corresponding to the BoundingBox
# This means that when Ghostscript renders it, the result needs no
# cropping, and the PDF MediaBox is correct.
#   c) the result is piped to Ghostscript and a PDF version written.
#
# It needs a Level 2 PS interpreter.
# If the bounding box is not right, of course, there will be problems.
#
# One thing not allowed for is the case of
# "%%BoundingBox: (atend)" when input is not seekable (e.g., from a pipe),
# which is more complicated.
# 
# emacs-page
# History
#  2009/09/27 v2.11 (Karl Berry)
#    * Fixed two bugs in the (atend) handling code (Martin von Gagern)
#    * Improved handling of CR line ending (Martin von Gagern)
#    * More error checking
#    * --version option
#    * Create source repository in TeX Live
#  2009/07/17 v2.9.11gw
#    * Added -dSAFER to default gs options
#	TL2009 wants to use a restricted variant of -shell-escape,
#	allowing epstopdf to run. However without -dSAFER Ghostscript
#	allows writing to files (other than given in -sOutputFile)
#	and running commands (through Ghostscript pipe's language feature).
#  2009/05/09 v2.9.10gw
#    * Changed cygwin name for ghostscript to gs
#  2008/08/26 v2.9.9gw
#    * Switch to embed fonts (default=yes) (J.P. Chretien)
#    * turned no AutoRotatePages into an option (D. Kreil) (default = None)
#    * Added resolution switch (D. Kreil)
#    * Added BSD-style license
#  2007/07/18 v2.9.8gw
#  2007/05/18 v.2.9.7gw (Gerben Wierda)
#    * Merged both supplied 2.9.6 versions
#  2007/05/15 v2.9.6tp (Theo Papadopoulo)
#    * Simplified the (atend) support
#  2007/01/24 v2.9.6sw (Staszek Wawrykiewicz)
#    * patched to work also on Windows
#  2005/10/06 v2.9.5gw (Gerben Wierda)
#    * Fixed a horrendous bug in the (atend) handling code
#  2005/10/06 v2.9.4gw (Gerben Wierda)
#    * This has become the official version for now
#  2005/10/01 v2.9.3draft (Gerben Wierda)
#    * Quote OutFilename
#  2005/09/29 v2.9.2draft (Gerben Wierda)
#    * Quote OutFilename
#  2004/03/17 v2.9.1draft (Gerben Wierda)
#    * No autorotate page
#  2003/04/22 v2.9draft (Gerben Wierda)
#    * Fixed bug where with cr-eol files everything up to the first %!
#    * in the first 2048 bytes was gobbled (double ugh!)
#  2002/02/21 v2.8draft (Gerben Wierda)
#    * Fixed bug where last line of buffer was not copied out (ugh!)
#  2002/02/18 v2.8draft (Gerben Wierda)
#    * Handle different eol styles transparantly
#    * Applied fix from Peder Axensten for Freehand bug
#  2001/03/05 v2.7 (Heiko Oberdiek)
#    * Newline before grestore for the case that there is no
#      whitespace at the end of the eps file.
#  2000/11/05 v2.6 (Heiko Oberdiek)
#    * %%HiresBoundingBox corrected to %%HiResBoundingBox
#  1999/05/06 v2.5 (Heiko Oberdiek)
#    * New options: --hires, --exact, --filter, --help.
#    * Many cosmetics: title, usage, ...
#    * New code for debug, warning, error
#    * Detecting of cygwin perl
#    * Scanning for %%{Hires,Exact,}BoundingBox.
#    * Scanning only the header in order not to get a wrong
#      BoundingBox of an included file.
#    * (atend) supported.
#    * uses strict; (earlier error detecting).
#    * changed first comment from '%!PS' to '%!';
#    * corrected (atend) pattern: '\s*\(atend\)'
#    * using of $bbxpat in all BoundingBox cases,
#      correct the first white space to '...Box:\s*$bb...'
#    * corrected first line (one line instead of two before 'if 0;';
# 
# Thomas Esser, Sept. 1998: change initial lines to find
# perl along $PATH rather than guessing a fixed location. The above
# construction should work with most shells.
#
# Originally by Sebastian Rahtz, for Elsevier Science
# with extra tricks from Hans Hagen's texutil and many more.
# emacs-page

### program identification
my $program = "epstopdf";
my $program_ident = '$Id$';
my $copyright = <<END_COPYRIGHT ;
Copyright 1998-2001 Sebastian Rahtz et al.
Copyright 2002-2009 Gerben Wierda et al.
Copyright 2009 Karl Berry et al.
License RBSD: Revised BSD <http://www.xfree86.org/3.3.6/COPYRIGHT2.html#5>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
END_COPYRIGHT
my $title = "$program $program_ident\n";

### ghostscript command name
my $GS = "gs";
$GS = "gswin32c" if $^O eq 'MSWin32';

### options
$::opt_outfile="";
$::opt_compress=1;
$::opt_debug=0;
$::opt_embed=1;
$::opt_exact=0;
$::opt_filter=0;
$::opt_gs=1;
$::opt_hires=0;
$::opt_gscmd="";
$::opt_res=0;
$::opt_autorotate="None";

### usage
my @bool = ("false", "true");
my $resmsg = $::opt_res ? $::opt_res : "[use gs default]";
my $rotmsg = $::opt_autorotate ? $::opt_autorotate : "[use gs default]";
my $usage = <<"END_OF_USAGE";
${title}Usage: $program [OPTION]... [EPSFILE]

Convert EPS to PDF, by default using Ghostscript.

Options:
  --help             display this help and exit
  --version          display version information and exit
  
  --outfile=FILE     write result to FILE
  --(no)compress     use compression       (default: $bool[$::opt_compress])
  --(no)debug        write debugging info  (default: $bool[$::opt_debug])
  --(no)embed        embed fonts           (default: $bool[$::opt_embed])
  --(no)exact        scan ExactBoundingBox (default: $bool[$::opt_exact])
  --(no)filter       read standard input   (default: $bool[$::opt_filter])
  --(no)gs           run ghostscript       (default: $bool[$::opt_gs])
  --(no)hires        scan HiResBoundingBox (default: $bool[$::opt_hires])
  --gscmd=VAL        pipe output to VAL    (default: $GS)
  --res=DPI          set image resolution  (default: $resmsg)
  --autorotate=VAL   set AutoRotatePages   (default: $rotmsg)
                      Recognized VAL choices: None, All, PageByPage
                      For EPS files, PageByPage is equivalent to All

Examples for producing 'test.pdf':
  * $program test.eps
  * produce postscript | $program --filter >test.pdf
  * produce postscript | $program -f -d -o=test.pdf

Example: look for HiResBoundingBox and produce corrected PostScript:
  * $program -d --nogs --hires test.ps >testcorr.ps

When reporting bugs, please include an input file and command line
options so the problem can be reproduced.

Report bugs to: tex-k\@tug.org
epstopdf home page: <http://tug.org/epstopdf/>
END_OF_USAGE

### process options
use Getopt::Long;
GetOptions (
  "help",
  "version",
  "outfile=s",
  "compress!",
  "debug!",
  "embed!",
  "exact!",
  "filter!",
  "gs!",
  "hires!",
  "gscmd=s",
  "res=i",
  "autorotate=s",
) or die $usage;

### help functions
sub debug {
  print STDERR "* @_\n" if $::opt_debug;
}
sub warning {
  print STDERR "==> Warning: @_\n";
}
sub error {
  die "$title!!! Error: @_\n";
}
sub errorUsage {
  die "$usage\n!!! Error: @_\n";
}

### help, version options.
if ($::opt_help) {
  print $usage;
  exit (0);
}

if ($::opt_version) {
  print $title;
  print $copyright;
  exit (0);
}


### get input filename
my $InputFilename = "";
if ($::opt_filter) {
  @ARGV == 0 or
    die errorUsage "Input file cannot be used with filter option";
  $InputFilename = "-";
  debug "Input file: standard input";
}
else {
  @ARGV > 0 or die errorUsage "Input filename missing";
  @ARGV < 2 or die errorUsage "Unknown option or too many input files";
  $InputFilename = $ARGV[0];
  #-r $InputFilename or error "\"$InputFilename\" not readable";
  debug "Input filename:", $InputFilename;
}

### option compress & embed
my $GSOPTS = "-dSAFER ";
$GSOPTS .= (" -dPDFSETTINGS=/prepress -dMaxSubsetPct=100 "
           . "-dSubsetFonts=true -dEmbedAllFonts=true ")
   if $::opt_embed; 
$GSOPTS .= "-dUseFlateCompression=false " unless $::opt_compress;
$GSOPTS .= "-r$::opt_res " if $::opt_res;
$resmsg= $::opt_res ? $::opt_res : "[use gs default]";
$GSOPTS .= "-dAutoRotatePages=/$::opt_autorotate " if $::opt_autorotate;
die "Invalid value for autorotate: '$::opt_autorotate' (use 'All', 'None' or 'PageByPage').\n"
    if ($::opt_autorotate and 
        not $::opt_autorotate =~ /^(None|All|PageByPage)$/);
$rotmsg = $::opt_autorotate ? $::opt_autorotate : "[use gs default]";

### option BoundingBox types
my $BBName = "%%BoundingBox:";
!($::opt_hires and $::opt_exact) or
  error "Options --hires and --exact cannot be used together";
$BBName = "%%HiResBoundingBox:" if $::opt_hires;
$BBName = "%%ExactBoundingBox:" if $::opt_exact;
debug "BoundingBox comment:", $BBName;

### option outfile
my $OutputFilename = $::opt_outfile;
if ($OutputFilename eq "") {
  if ($::opt_gs) {
    $OutputFilename = $InputFilename;
    if (!$::opt_filter) {
      $OutputFilename =~ s/\.[^\.]*$//;
      $OutputFilename .= ".pdf";
    }
  }
  else {
    $OutputFilename = "-"; # standard output
  }
}
if ($::opt_filter) {
  debug "Output file: standard output";
}
else {
  debug "Output filename:", $OutputFilename;
}

### option gscmd
if ($::opt_gscmd) {
  debug "Switching from $GS to $::opt_gscmd";
  $GS = $::opt_gscmd;
}

### option gs
if ($::opt_gs) {
  debug "Ghostscript command:", $GS;
  debug "Compression:", ($::opt_compress) ? "on" : "off";
  debug "Embedding:", ($::opt_embed) ? "on" : "off";
  debug "Rotation:", $rotmsg;
  debug "Resolution:", $resmsg;
}

### emacs-page
### open input file
open(IN, "<$InputFilename") or error "Cannot open",
  ($::opt_filter) ? "standard input" : "\"$InputFilename\": $!";
binmode IN;

### open output file
my $outname;  # used in error message at end
if ($::opt_gs) {
  my $pipe = "$GS -q -sDEVICE=pdfwrite $GSOPTS" .
          " -sOutputFile=\"$OutputFilename\" - -c quit";
  debug "Ghostscript pipe:", $pipe;
  open(OUT,"|$pipe") or error "Cannot open Ghostscript for piped input";
  $outname = $GS;
}
else {
  open(OUT,">$OutputFilename") or error "Cannot write \"$OutputFilename\"";
  $outname = $OutputFilename;
}
binmode OUT;

# reading a cr-eol file on a lf-eol system makes it impossible to parse
# the header and besides it will read the intire file into yor line by line
# scalar. this is also true the other way around.

### emacs-page
### scan a block, try to determine eol style

my $buf;
my $buflen;
my @bufarray;
my $inputpos;

# We assume 2048 is big enough.
my $EOLSCANBUFSIZE = 2048;

$buflen = read(IN, $buf, $EOLSCANBUFSIZE);
if ($buflen > 0) {
  my $crlfpos;
  my $lfpos;
  my $crpos;

  $inputpos = 0;

  # remove binary junk before header
  # if there is no header, we assume the file starts with ascii style and
  # we look for a eol style anyway, to prevent possible loading of the
  # entire file
  if ($buf =~ /%!/) {
    # throw away binary junk before %!
    $buf =~ s/(.*?)%!/%!/o;
    $inputpos = length($1);
  }
  $lfpos = index($buf, "\n");
  $crpos = index($buf, "\r");
  $crlfpos = index($buf, "\r\n");

  if ($crpos > 0 and ($lfpos == -1 or $lfpos > $crpos+1)) {
    # The first eol was a cr and it was not immediately followed by a lf
    $/ = "\r";
    debug "The first eol character was a CR ($crpos) and not immediately followed by a LF ($lfpos)";
  }

  # Now we have set the correct eol-character. Get one more line and add
  # it to our buffer. This will make the buffer contain an entire line
  # at the end. Then split the buffer in an array. We will draw lines from
  # that array until it is empty, then move again back to <IN>
  $buf .= <IN> unless eof(IN);
  $buflen = length($buf);

  # Some extra magic is needed here: if we set $/ to \r, Perl's re engine
  # still thinks eol is \n in regular expressions (not very nice) so we
  # cannot split on ^, but have to split on a look-behind for \r.
  if ($/ eq "\r") {
    @bufarray = split(/(?<=\r)/ms, $buf); # split after \r
  }
  else {
    @bufarray = split(/^/ms, $buf);
  }
}

### getline
sub getline
{
  if ($#bufarray >= 0) {
    $_ = shift(@bufarray);
  }
  else {
    $_ = <IN>;
  }
  $inputpos += length($_) if defined $_;
  return defined($_);
}

### scan first line
my $header = 0;
getline();
if (/%!/) {
  # throw away binary junk before %!
  s/(.*)%!/%!/o;
}
$header = 1 if /^%/;
debug "Scanning header for BoundingBox";
print OUT;

### variables and pattern for BoundingBox search
my $bbxpatt = '[0-9eE\.\-]';
               # protect backslashes: "\\" gets '\'
my $BBValues = "\\s*($bbxpatt+)\\s+($bbxpatt+)\\s+($bbxpatt+)\\s+($bbxpatt+)";
my $BBCorrected = 0;

sub CorrectBoundingBox
{
  my ($llx, $lly, $urx, $ury) = @_;
  debug "Old BoundingBox:", $llx, $lly, $urx, $ury;
  my ($width, $height) = ($urx - $llx, $ury - $lly);
  my ($xoffset, $yoffset) = (-$llx, -$lly);
  debug "New BoundingBox: 0 0", $width, $height;
  debug "Offset:", $xoffset, $yoffset;

  print OUT "%%BoundingBox: 0 0 $width $height$/";
  print OUT "<< /PageSize [$width $height] >> setpagedevice$/";
  print OUT "gsave $xoffset $yoffset translate$/";
}

### emacs-page
### scan header
if ($header) {
  HEADER: while (getline()) {
    ### Fix for freehand bug ### by Peder Axensten
    next HEADER if(!/\S/);

    ### end of header
    if (!/^%/ or /^%%EndComments/) {
      print OUT;
      last;
    }

    ### BoundingBox with values
    if (/^$BBName$BBValues/o) {
      CorrectBoundingBox $1, $2, $3, $4;
      $BBCorrected = 1;
      last;
    }

    ### BoundingBox with (atend)
    if (/^$BBName\s*\(atend\)/) {
      debug $BBName, "(atend)";
      if ($::opt_filter) {
        warning "Cannot look for BoundingBox in the trailer",
                "with option --filter";
        last;
      }
      my $pos = $inputpos;
      debug "Current file position:", $pos;

      # looking for %%BoundingBox
      while (getline()) {
        # skip over included documents
        my $nestDepth = 0;
        $nestDepth++ if /^%%BeginDocument/;
        $nestDepth-- if /^%%EndDocument/;
        if ($nestDepth == 0 && /^$BBName$BBValues/o) {
          CorrectBoundingBox $1, $2, $3, $4;
          $BBCorrected = 1;
          last;
        }
      }

      # go back
      seek(IN, $pos, 0) or error "Cannot go back to line \"$BBName (atend)\"";
      last;
    }

    # print header line
    print OUT;
  }
}

### print rest of file
while (getline()) {
  print OUT;
}

### emacs-page
### close files
close(IN);
print OUT "$/grestore$/" if $BBCorrected;
close(OUT);

# if ghostscript exited badly, we should too.
if ($? & 127) {
  error(sprintf "Writing to $outname failed, signal %d\n", $? & 127);
} elsif ($? != 0) {
  error(sprintf "Writing to $outname failed, error code %d\n", $? >> 8);
}

warning "BoundingBox not found" unless $BBCorrected;
debug "Ready.";
