#!/usr/bin/perl
# General Purpose regular expression matcher for HTML content
# Copyright (C) Neptune Web, Inc. 2006

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# $Id: dwreplace.pl,v 1.1 2014/05/01 14:25:16 root Exp root $


use Getopt::Long;

my $replacementfile;
my $searchonly;
my ($showexample);
my $verbose;
my $casesensitive;
my $null;
my $matchesonly;

Getopt::Long::GetOptions("rfile=s" => \$replacementfile, "s+" => \$searchonly, "e+" => \$showexample, "v+" => \$verbose, 
			 "ni+" => \$casesensitive, "null+" => \$null, "m+" => \$matchesonly);

if (!$replacementfile && !$showexample) {
    print <<'END_OF_MARKER';

usage: dwreplace (--s) --rfile=rfile file1 <file2 ... file(n)>\n\n

Flags:
--rfile=<file> => where file is the rfile to use (this is a mandatory argument)
--s            => search only, do not replace
--e            => show an example rfile
--v            => verbose mode, shows detailed matching info and highlighted text for changes
--ni           => case sensitive mode (not insensitive)
--m            => matches only, do not show unmatched files
--null	       => assume file list will be null separated and piped to stdin, similar to xargs
				  e.g. find . -print0 | dwreplace --rfile=blah.rfile --null
				  Note: you can also pass regular non-null terminated filenames to stdin. 
					ignore the --null in this case (and no file-names-to-match on command line. 
					it's either command line or stdin, no mixing allowed)
				  e.g. find . -print | dwreplace --ffile=blah.rfile 

END_OF_MARKER

exit(1);

} elsif ($showexample) {
    
######################################### SAMPLE RFILE ##########################
print <<'END_OF_MARKER';

# Example rfile:

$OLD[0] = <<'END_OF_TEXT';
Sample Love Letter:
END_OF_TEXT

$NEW[0] = <<'END_OF_TEXT';
<font color="blue">Sample Love Letter:</font>
END_OF_TEXT

# Reversing the file to match a <table (unkown) ..(unkown) known text

$OPTIONS[1] = [ isregexp , reversefile,  casesensitive ];

$OLD[1] = 'ot ereh kcilC.*?elbat<';

$NEW[1] = '<p><center>{$sendbutton}</center></p>';

## if you want to interpolate from a regexp, those things found using
## brace notation.  use in conjunction with
## "escape_perl_regular_expression" program if your regular expression
## contains alot of whitespace and HTML

# Another words -- you can't put a HERE document for the right side (new text)
# if you are doing interpolation! There should be a way to make this work, however.

$OPTIONS[2] = [ isregexp , interpolator ];

$OLD[2] = '<SPAN\s*CLASS=\"body\">(.*?)<a\s*href=\"#\"\s*onclick=\"backToTop\(0\)\">Back\s*To\s*Top<\/a>';

$NEW[2] = '<editable>$1</editable><a href="#" onclick="backToTop(0)">Back To Top</a>';

# Example 4 most advanced. Pull out all absolute URLS and replace with an interstitial page. 

sub urlEncode {
    my ($toencode) = @_;
    return undef unless defined($toencode);
    $toencode=~s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
    return $toencode;
}

$OLD[3] = '(href|src)="?(http:\/\/.*?)[">\s]';
$NEW[3] = '"speedbump.html?page=$1=\"" . urlEncode($2) . "\""';

$OPTIONS[3] = [ isregexp , interpolator , eflag  ]; # use the eflag to evaluate the right hand side.

######################################### SAMPLE RFILE ##########################
END_OF_MARKER

    exit();
} else {
	if (!open(F,"$replacementfile")) {
		print STDERR "Your rfile $replacementfile could not be opened.\n";
		exit(-599);
	}
	my $f; # read in the file.
	while (<F>) {
        $f .= $_;
	}
	close (F);
	eval($f);
    if ($@) {
	if ($@ =~ /did not return a true value/i) {
	    print STDERR "Your rfile ($replacementfile) must return a true value... \nYou may need to put a '1;' at the bottom of the rfile. run with --e for an example rfile\n"; print STDERR "Error: $@\n"; 
	} else {
	    print STDERR "Your rfile ($replacementfile) did not compile properly\n"; print STDERR "Error: $@\n"; 
	}
	exit()
	};
}

my @infiles = @ARGV;

if ($#ARGV == -1) {
	# make check for files coming from stdin, possibly null terminated.
	if ($null) {
    	my $temp_val = $/;
    	$/ = "\0";
	}
	while (<>) {
		chop;
    	push(@infiles,$_);
	}
	if ($#infiles == -1) {
		print "no files specified\n";
		exit();
	}

	if ($null) { $/ = $temp_val; }
} 

if (!$null && $#infiles == 0 && $infiles[0] =~ /\0/ ) { # check for null terminated arguments without the --null, in case the user forgot.
	print "did you mean to pass --null?\n";
	exit();
}

if ($#NEW == -1 || $#OLD == -1) {
	print "nothing to do (OLD OR NEW EMPTY)\n";
	exit();
}

if (!($#NEW == $#OLD)) {
    print "NEW, OLD, AND OPTIONS arrays are of differing size\n";
    exit();
}

if ($#OPTIONS > $#NEW) {
    print "options array larger than newtext array.\n";
    exit();
}
if ($#OPTIONS > $#OLD) {
    print "options array larger than newtext array.\n";
    exit();
}


my $j;
foreach ($j = 0; $j <  $#NEW; $j++) {
    if (!defined($OLD[$j]) || !defined($NEW[$j])) {
	print "NEW[$j], OLD[$j], AND OPTIONS[$j] are empty.\n";
	exit();
    }
}

my $filename;

# loop through each file provided on the command prompt
foreach $filename (@infiles) {
    if (!open G, "<$filename") { print STDERR "Cannot open file $filename for reading\n"; next; }
    undef $/; 
    my $file = <G>; $/ = "\n";

    my $index;
    my $matchcount = 0;
    my %failedMatches;

    my %mperstr;         # match per str
    my $mperstrcnt = 0;  #  "     "   "  count
    my $hlitfile = $file;        # file with parts to be changed highlighted

    for ($index = 0; $index <= $#NEW; $index++) {
	my $regexp;
	my $endingModifiers;
	if ($OPTIONS[$index] && grep(/^isregexp$/,@{$OPTIONS[$index]})) {
	    $regexp = $OLD[$index];
	} else {
	    $regexp = removeWhiteSpaceAndEscapeRegexp($OLD[$index]);
	}
	# the main 'workhorse' regular expression
	my $finalRegexp;
	my $reversedRightHandSide; # only used if reversing, so as not to override the actual global variables.
	
	if ($OPTIONS[$index] && grep(/^isregexp$/,@{$OPTIONS[$index]}) && grep(/^interpolator$/,@{$OPTIONS[$index]})) {
	    my $rightSideExp = $NEW[$index];
	    # it seems that they never want / in the right hand side if they are doing interpolation on right.
	    $rightSideExp  =~ s/([\/])/\\$1/g;
	    if (!$searchonly) {
		$finalRegexp = '$file =~ ' .  "s/\$regexp/" . $rightSideExp. "/";
	    } else {
		$finalRegexp = '$file =~ ' .  "/\$regexp/";
	    }
	} else {
	    
	    if ($OPTIONS[$index] && grep(/^reversefile$/,@{$OPTIONS[$index]}) ) {
		# reverse the right hand side for convenience ....
		$reversedRightHandSide = scalar reverse $NEW[$index];
		if (!$searchonly) {
		    $finalRegexp = '$file =~ ' .  "s/\$regexp/\$reversedRightHandSide/";
		} else {
		    $finalRegexp = '$file =~ ' .  "/\$regexp/";
		}
	    } else {
		if (!$searchonly) {
		    $finalRegexp = '$file =~ ' .  "s/\$regexp/\$NEW[\$index]/";
		} else {
		    $finalRegexp = '$file =~ ' .  "/\$regexp/";
		}
	    }
	}
	if (!$searchonly && $OPTIONS[$index] && grep(/^nonglobalreplace$/,@{$OPTIONS[$index]}) ) {
	    $endingModifiers = "is";
	    if ($casesensitive ||grep(/^casesensitive$/,@{$OPTIONS[$index]})) {
		$endingModifiers = "s";
	    }
	} elsif (!$searchonly) {
	    $endingModifiers = "isg";
	    if ($casesensitive || grep(/^casesensitive$/,@{$OPTIONS[$index]})) {
		$endingModifiers = "sg";
	    }
	} else {  # search only
	    $endingModifiers = "isg";
	    if ($casesensitive || grep(/^casesensitive$/,@{$OPTIONS[$index]})) {
		$endingModifiers = "sg";
	    }
	}
	# sometimes you'll need to reverse the contents of the file.
	if ($OPTIONS[$index] && grep(/^reversefile$/,@{$OPTIONS[$index]})) {
	    $file = scalar reverse $file;
	}

	#print "\n\n------\n\n$regexp\n\n$finalRegexp\n\n$file\n\n-----\n\n";

	# count how many times a particular match occurs
	my $rr = "\$file =~ " . "/$regexp/" . $endingModifiers;
	while (eval($rr)){
	    die "Error ---: $@\n Code:\n$rr\n" if ($@);
	    $mperstrcnt++; 
	}
	$mperstr{$index} = $mperstrcnt;
	$mperstrcnt = 0;

	# if you want to see what you are replacing highlighted within the file, only in verbose mode
	if ($verbose) {
	    $hlitfile = highlightFile($regexp, $endingModifiers, $hlitfile);
        }
	$finalRegexp .= $endingModifiers;

	# use the e flag when we want to evaluate the right side of the reg exp. during replace
	if (!$searchonly && grep(/^eflag$/,@{$OPTIONS[$index]})) {
	    $finalRegexp .= "e";
	}

	if (eval($finalRegexp)) {
	    die "Error ---: $@\n Code:\n$finalRegexp\n"  if ($@);  
	    $matchcount++;
	} else {
	    # count your failed matches...
	    $failedMatches{$index} = 1;
	};
# sometimes you'll need to reverse the contents of the file, but don' forget to put it back!!
	if ($OPTIONS[$index] && grep(/^reversefile$/,@{$OPTIONS[$index]})) {
	    $file = scalar reverse $file;
	}
    }
    if (!$searchonly && $matchcount > 0) {
	open G, ">$filename" or print STDERR "Cannot open file $filename for writing";
	print G "$file";
	close G;
    }
	if ($matchcount > 0 || !$matchesonly) {
    print "$filename ($matchcount matches found)\n";
	}

    if($verbose) {    # sometimes you may want more information on matching, triggers verbose mode
	my $ii = 1;
	my $value;    # print out how many matches for each match type 

        print $hlitfile . "\n";

        print "Times each match is found data below: \n";
        foreach $value (keys %mperstr) {
	    # ii --> match index,   hash value --> how many of that type of match was made
	    print "\t$ii -- $mperstr{$value} times\n"; 
	    $ii++;
	}
    }
}

sub removeWhiteSpaceAndEscapeRegexp() {
    my ($ins) = @_;
# remove all regexp meaningful characters.
    $ins =~ s/([\@\$\|\*\?\]\[\^\/\+\.\"\(\\)])/\\$1/isg;
    # add whitespace independence, but only after weird (regular expression) chars have been removed.
    $ins =~ s/\s+/\\s*/isg;
    return $ins;
}

sub highlightFile() {
    my ($r, $endMods, $f) = @_;

    my $hfile = $f;

    require POSIX;       
    use Term::Cap;  # use the terminal feature to create highlighted text on the screen
	    
    my $term = $ENV{TERM} || 'vt100';
    my $terminal;
	    
    my $termios = POSIX::Termios->new();
    $termios->getattr;
    my $ospeed = $termios->getospeed;
	    
    $terminal =  Term::Cap->Tgetent( { TERM=>undef, OSPEED=>$ospeed } );
	    
    print "Error from eval: $@" if ($@);
	    
    my ($SO, $SE) = ($terminal->Tputs('so'), $terminal->Tputs('se'));

    my $exp = '$hfile =~ ' . "s/($r)/\${SO}\$1\${SE}/" . $endMods;

    eval($exp);

    die "Error ---: $@\n Code:\n$exp\n" if ($@);
   
    return $hfile;
}


