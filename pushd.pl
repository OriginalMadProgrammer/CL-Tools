#!/usr/local/bin/perl
#
#   "pushd.pl +Man | nroff -man | more" to get man page
#
# invokement (sh, ksh):
#    if [ "${PUSHD:-not defined;}" = "not defined;" ]; then
#    #  Initialize stack (may set to a preset value)
#	   #if "home" directory is symbolic link: chase down real home
#	   PUSHD=`pwd` && cd && HOME=`pwd` && export HOME
#	   cd $PUSHD; 
#	PUSHD=""
#	export PUSHD
#     fi
#    pushd() { eval `pushd.pl $*;`; }
#    pd()    { eval `pushd.pl +Pd $*;`; }
#    popd()  { eval `pushd.pl +Popd $*;`; }
#    dirs()  { pushd.pl +Dirs $*; }
#
#  NOTE: this code goes back to the days of perl-4, before there was
#  	OO, "my", or many other neat features. And for years after perl-5
#	was introduced this was kept backwards compatible with 
#	perl-4. I no longer feel a need to to that, but then this
#	code is not changing much anymore (except herein I will avoid my).
#					Gilbert
#
# ksh features
#  + CDPATH	defines CD path if not found
#  + OLDPWD	defines previous CD (used when just "-" is found as dirname)
#  + -P & -L 	physical vs logical paths
#  + cd old new	equivalent to s/old/new/g (suspect g). no stack change
#
#
#...............................................................................
$RevPushd = '@(#)pushd.pl	2.8 02/02/97 17:39:14';
$RevPushd = '$Id: pushd.pl,v 2.15 2002/10/14 02:46:29 ghealton Exp $';

$Copyright = "Changes after public domain version "
		. "Copyright 2002 by Gilbert Healton";

$ColsMax = 70;		#maximum columns the Dirs command is to use

$dirDelim = ':';	#official directory delimiter (was originally ' ',
			##and that still works alone for backwards compat.)

$csplitDelim = ':';	#CDPATH delimiter

$UnCshAlias = "repeat 1 ";	#csh: prefix to prevent built in csh command 
##				##embedded within an alias to that command from 
##				##running as a nested command (run the built-in)
		#once upon a time some C-shells accepted "\cd"
		#notation as "non-alias version of cd", but
		#apparently, no more or not Sun.
		#HOWEVER, it appears that "repeat 1 xxxx" bypasses 
		##aliases for all C-shells.

$nextOLDPWD = undef;	#becomes defined if OLDPWD needs to be set.
##			#value is shell command required to set for current
##			#shell

## stuff common to multiple functions
$PUSHD = $ENV{"PUSHD"};			#original PUSHD stack value
$PUSHD =~ s/^\s+//;			#ensure no leading spaces
$PUSHD =~ s/\s+$//;			#wipe trailing spaces (DOES HAPPEN)
@Dirs = ( $PUSHD =~ /^$dirDelim/ )	#legacy or modern split needed?
	? split( /$dirDelim+/, $PUSHD )		#modern: only embedded delim
	: split( /[$dirDelim\s]+/, $PUSHD );	#legacy: spaces or delim
@Dirs = grep( /./, @Dirs );		#ensure only well defined elements kept

## other useful stuff
$HOME = $ENV{'HOME'};	#home dir name

require "getopts.pl";
$opt_1 = 0;		#-1: dir is to list one directory-per-line
$opt_c = 0;		#-c: running under csh shell. set by &Initialize to 
##			#    prefix for csh commands to indicate they are 
##			#    built-in csh commands rather than an alias.
$opt_L = 0;		#-L: for LOGICAL directory paths (see `cd -L`)
$opt_P = 0;		#-P: for PHYSICAL directory paths (see `cd -P`)
    			#    NOTE for -L & -P: &Initiailze sets to undef if false
			#	$opt_L set to ' -L' if true.
			#	$opt_P set to ' -P' if true.
			#    $opt_L and $opt_P are mutually exclusive. only
			#    one will remain on if both are selected.
$opt_LP = undef;	#    becomes the L or P setting. undef if neither.
			#	RESTRICTION: not for use within system() or
			#	   open()s using pipes.
$opt_p = 0;		#-p: set prompt to include directory name
$opt_r = 0;		#-r: reorder stack
$opt_s = 0;		#-s: silence: do not print directory name
$opt_S = 0;		#-S: sort stack (after any selection)
$opt_t = 0;		#-t: tilde conversions 
			#    #-t only applies to dirs we show. we ALWAYS
			#    ##expand incoming ~'s we observe to ${HOME}.
$opt_x = 0;		#-x: remove (most) duplicates from stack
$opt_z = 0;		#-z: print debugging information

( $MyName = $0 ) =~ s'.*/'';		#just get the program name

$OLDPWD = $ENV{'OLDPWD'};		#get OLDPWD or set to undef

$STDSHELL = STDOUT;	#symbolic name for output to shell

$RCS = $RevPushd =~ /\$Id.*\$/		#determine if RCS/CVS or SCCS style
	? 1				##revision information.
	: 0;				##(does NOT cope with ClearCase, but
					## then I don't use CC at home)
## figure out what we are really to do
&goManPage if $ARGV[0] eq "+Man";
&goDirs if $ARGV[0] eq "+Dirs";
&goPopd if $ARGV[0] eq "+Popd";
&goPushd( "pd" ) if $ARGV[0] eq "+Pd";

&goPushd();

#should never have gotten here!
print STDERR "$MyName: ", __FILE__, "(", __LINE__, "): PROGRAM BUG\n";
exit(99);


########################################################################
#
#   `dirs` command processing
#	# &goDirs();
#	# exits on completion with appropriate exit code.
#
sub goDirs
{
    shift @ARGV;		#discard known "+Dirs"
    &Initialize( "dirs", "1cpStx" );

    $ColsMax = 1 if $opt_1;

    @Dirs = &ReduceStack( @Dirs ) if $opt_x;

    @Dirs = sort @Dirs if $opt_S;	#do any requested sorting

    unshift( @Dirs, $Pwd );	#put the current directory in front

    local( $Cols ) = 0;

    while( @Dirs )
    {
	local($tmp) = shift( @Dirs );	#get next directory name
	
	$tmp = &Tilde( $tmp ) if $opt_t; #use tilde compression

	$tmp = " $tmp";			#tack on space

	if ( $opt_1 )
	{   #one entry per line
	    print "\n" if $Cols;
	}
	else
	{   #normal printing: stack up, but don't overflow line 
	    if ( $Cols + length($tmp) > $ColsMax )
	    {
		print "\n  ";
		$Cols = 2;
	    }
	}
	print $tmp;

	$Cols += length( $tmp );
    }
    print "\n" if $Cols;

    exit(0);			#successful completion
}


########################################################################
#
#   `popd` command processing
#	# &goPopd()
#	# exits on completion with appropriate exit code.
#
sub goPopd
{
    shift @ARGV;		#discard known "+Popd".
    &Initialize( "popd", "cLPpsStxz" );

    @Dirs = &ReduceStack( @Dirs ) if $opt_x;	#clean stack, if desired

    unless ( @Dirs )
    {
	print STDERR "$MyName: STACK EMPTY\n";
	print $STDSHELL "false\n";
	exit(1);
    }

    local( $Dir ) = shift @Dirs;	#get stack to return to 

    &Preselect(1, $Dir);		#validate $Dir and set $c

    @Dirs = sort @Dirs if $opt_S;	#do any requested sorting

    print $STDSHELL 
	    "${opt_c}cd$opt_LP ${Dir} $c", 
	    $opt_s ? "" : ( " && echo '" . &Tilde($Dir) . "' " ),
	    "; ",
	    &ShowStack( @Dirs ), 
	    $nextOLDPWD, 
	    "\n";
	#NOTE: "popd" sets new PUSHD even on bad directory selection.
	# this allows stack to be flushed if bad names ever get
	# into it.

    exit(0);			#successful completion
}


########################################################################
#
#   `pushd` and `pd` command processing
#	# &goPushd() or &goPushd("pd");
#	# expects:
#	   # @ARGV: unprocessed command line args (arguments for us!)
#	# exits on completion with appropriate exit code.
#
sub goPushd
{
    local($Pd) = @_;		#remember if pd or pushd
    shift( @ARGV ) if $Pd;	#pop off known "+Pd" from `pd` argument list

    if ( defined $OLDPWD  &&  $ARGV[$#ARGV] eq '-' )
    {   #have an OLDPWD variable and it looks like we want to use it

    }
    &Initialize( $Pd ? "pd" : "pushd", "cLPprsStxz" );

    @Dirs = &ReduceStack( @Dirs ) if $opt_x;

    if ( @ARGV == 0 )
    {   #exchange the current directory with the top member of the stack
	if ( @Dirs == 0 )
	{
	    print STDERR "$MyName: STACK EMPTY\n";
	    print $STDSHELL "false\n";
	    exit(1);
	}

	local( $Dir ) = shift @Dirs;	#get stack to swap to 

	&Preselect(0, $Dir);		#validate $Dir and set $c

	@Dirs =				#do any requested sorting
		    ( $Dirs[0], sort @Dirs[1 .. $#Dirs] ) if $opt_S;	

	print $STDSHELL "${opt_c}cd$opt_LP $Dir $c && ", 
		&ShowStack( $Pwd, @Dirs ),  $nextOLDPWD,
		$opt_s ? "" : ( " && echo '" . &Tilde($Dir) . "'" ), "\n";
	exit(0);
    }

    #### PUSHING INTO STACK
    # 	   # pd/pushd  newdir;	#simple push of newdir on stack
    #	   # pd/pushd +n	#rotate stack n entries [n is numberic, 0=none]
    #	   # pd =symbolic	#rotate stack to bring symbolic match to top
    #
    $Dir = shift @ARGV;		#get the target directory

    if ( $Pd  &&  $Dir =~ /^=/ )
    {   #symbolic look up by name (MUST BE BEFORE "+" ROTATIONS!!!!!!!)
	$Dir = &RotateStack;	#change symbolic rotation to numeric rotation
    }

    if ( $Dir =~ /^\+\d+$/  &&  @ARGV == 0 )
    {   #rotate stack by numeric position
	if ( @Dirs == 0 )
	{
	    print STDERR "$MyName: STACK EMPTY +\n";
	    print $STDSHELL "false\n";
	    exit(1);
	}

	local($n) = $Dir;
	$n =~ s/\+//;		#wipe the known "+" to get just the rotation
	unshift(@Dirs, $Pwd);	#put current directory on top of stack
	### $n += 1;		#(do this later, only if appropriate)

	if ( $n > 0  &&  $n > @Dirs )
	{
	    print STDERR "$MyName: +$n is larger than stack depth\n";
	    $n %= @Dirs;	#truncate into range and continue on
	}

	unless( $opt_r )
	{   #normal rotation (not reordering)
	    $n++;		#bias count to allow for $Pwd in @Dirs

	    while ( $n-- > 0 ) 
	    {   #keep rotating the stack
		$Dir = shift @Dirs;		#shift off the head
		push( @Dirs, $Dir );		#put back on bottom of stack
	    }
	}
	else
	{   #-r reordering stack
	    $Dir = splice( @Dirs, $n, 1 );	#extract n'th element
	    ## ZZZ unshift( @Dirs, $Dir );
	}
    }
    elsif ( @ARGV )
    {   #argument(s) left: ksh style string substitution on current directory
	#   DOES NOT REFERENCE ENTRIES IN THE STACK

	unless ( @ARGV & 1 )
	{   #warn if more than two arguments were provided
	    print STDERR "$MyName: ODD NUMBER OF ARGUMENTS: \"",
	    		join( "\", \"", $Dir, @ARGV ), "\"\n";
	    print $STDSHELL "false\n";
	    exit 1;
	}

 	unshift( @ARGV, $Dir );		#put back onto @ARGV

	$Dir = "";
	local($pwdTmp) = $Pwd;

	while( @ARGV )
	{
	    local($old) = shift @ARGV;
	    local($new) = shift @ARGV;		#capture replacement string


	    local($oldRe) = quotemeta( $old );	#get RE safe strings we want
	    if ( $pwdTmp =~ s/^(.*?)$oldRe// )	#delete any matching strings
		    # NOTE: tested GNU's ksh: only does single substation
		    #  thus we avoid the "g" global modifier.
	    {   #found a match... becomes new $Dir
		$Dir .= $1 . $new;		#place in new directory
	    }
	    else
	    {   #did not find a match: warn operator, but continue anyway
		# under the assumption dir will no be there.
		print STDERR "$MyName: did not match \"$new\"\n";
	    }
	}

	$Dir .= $pwdTmp;		#any leftover chars terminate $Dir

	unshift( @Dirs, $Pwd );		#ensure previous directory in stack
    }
    else
    {   # push of simple name onto stack. 
	# no magic in name so it is an error if the directory does not exist.

	if ( $Dir eq '-'  &&  defined $OLDPWD )
	{   #it appears that we are to return to $OLDPWD
	    $Dir = $OLDPWD;		#select this directory for the push
	}


	if ( $Dir !~ m"^/"  &&  ( $CDPATH = $ENV{'CDPATH'} ) )
	{   #relative directory: try it relative to $CDPATH
	    # (if CDPATH exists and does not contain ".", do not search ".")
	    @CDPATH = 		#break down into dir list
			grep( /./,
			    split( /\s*${csplitDelim}+\s*/, $CDPATH ) ); 

	    foreach $dir ( @CDPATH )
	    {   #try to find directory within CDPATH list
		next unless $dir;		#ignore null entries
		$dir =~ s"^\~/"$HOME/";		#do tilde expansion on CDPATH
		$dir =~ s`^\~([-.\w]+)(.?)`
			    #  look up user names the hard way
			    local($user,$more) = ( $1, $2 );	#user name
			    local($path) = $user . $more;	#default name
			    local(@pw) = getpwnam( $user );
			    local($dir) = $pw[7];	#get directory
			    $path = $dir if ( @dir  &&  $dir ne ''  &&  -d $dir 
			    		&&  ( $more eq ''  ||  $more eq '/' ) );
			    $path =~ s"/+$"";	#wipe trailing slashes
			    $path;		#substitute this path
			`e;
		local($try) = "$dir/$Dir";	#directory to try
		if ( -d "$try" )		#directory exists?
		{   #found a directory: select it
		    $Dir = "$try";  	#remember this directory
		    last;			#stop the presses!
		}
	    }
	}

	unshift( @Dirs, $Pwd );		#put current directory onto stack
    }

    # pushing to a new directory
    $Dir =~ s"^\~/"$HOME/";		#do tilde expansion

    &Preselect(0, $Dir);		#validate $Dir and set $c

    @Dirs = sort @Dirs if $opt_S;	#do requested sort

    print $STDSHELL "${opt_c}cd$opt_LP $Dir $c && ", &ShowStack( @Dirs ), 
		$nextOLDPWD,
		$opt_s ? "" : ( " && echo '" . &Tilde($Dir) . "'" ), "\n";

    exit(0);
}


########################################################################
#
#   `pushd.pl +Man` manual page requests
#	# exits on completion with appropriate exit code.
#
sub goManPage
{
    print ".\n";
    print ".ds 7i ", $RevPushd, "\n";	#name, with magic info
    print ".\n";

    if ( $RCS )
    {
	@Id = split( /\s+/, $RevPushd );	#split into fields
	# $Id: pushd.pl,v 2.15 2002/10/14 02:46:29 ghealton Exp $

	print ".ds 7d ", $Id[3], "\n";	#revision date
	print ".ds 7r ", $Id[2], "\n";	#revision
    }
    else
    {
	## @(#)termcap.src 1.33 89/03/22 SMI; from UCB 5.28 6/7/86
	@Id = split( /\s+/, $RevPushd );	#split into fields

	print ".ds 7d ", $Id[2], "\n";	#revision date
	print ".ds 7r ", $Id[1], "\n";	#revision
    }
    print ".\n";
    print ".ds 7c $Copyright\n";

    while( <DATA> )
    {
	print $_;
    }
    exit(0);
}


########################################################################
#
#   Preselect -- ensure directory to be selected is valid
#	# &Preselect( ChangeEvenOnError, directorToPreselect )
#	# Get the "real" path name, as known to "pwd".
#	# Ensures "pd ..", etc., prints a good directory name
#	# under -p, sets "$c = prompt =" if -C was requested, else $c = "".
#	# return value: undefined
#	   # defines $c to shell command that sets command line prompt on -p
#
sub Preselect
{
    local($ChangeOnError) = shift @_;	#determine if changing even on error
    local($Dir) = shift @_;		#save directory name we want

    local($dir) = $Dir;		#copy directory to local name
    $dir =~ s"^\~/"$HOME/";	#ALWAYS translate ~ back to full $HOME
    ##				##(for "sh" in "system(3)")

    local($_) = &pushdPwd($dir);	#get path to $dir
    unless ( defined $_ )
    {   #error return from pushdPwd
	print $STDSHELL &ShowStack( @Dirs ), "; " if $ChangeOnError;
	print $STDSHELL "false\n";	#error exit w/o "cd"
	exit 1;
    }

    $Dir = $_ if $_ =~ /^.*\S+.*$/ && -d $_; #set directory to this if valid

    if ( $opt_p )
    {   #set directory
	$c = $opt_c ? "&& set prompt='$Prompt1$Dir$Prompt2'" :
		      "&& PS1='$Prompt1$Dir$Prompt2' && export PS1";
    }
    else
    {
	$c = "";
    }
}



########################################################################
#
#   pushdPwd -- pwd specific to pushd
#     # use pwd to determine WHICH directory we are truly in
#	#  NOTE: in times of old `pwd` would show the true path name. 
#	#  sadly it no longer does so, or at least not the default.
#	#  pwd programs default to "logical" operations tend to 
#	#  have a -P for "physical" that makes them behave as before.
#	#  returns directory name on success, undef on error.
#	#  NOTE: POSIX.2 compliant pwd commands do NOT support -LP,
#	   even if the local shells do. Rely on `cd` to do required -LP.
#	#  NOTE: the shell started by the following open() is NOT the
#	   same shell as the user shell. Indeed it may be a minimal
#	   Borne shell who's cd does not support -LP.
#
sub pushdPwd
{
    local( $dir ) = shift @_;		#directory to go to

    unless ( open( DIR, "cd $dir && pwd 2>&1 |" ) )
    {   #super duper problem: does not normally get here for "dir not found"
	print STDERR "$MyName: CAN NOT SELECT \"$dir\": PIPE FAILURE $?\n";
	return undef;
    }

    local($_) = <DIR>;			#read directory name
    close(DIR);
    s/\s+$//;				#safe chop of terminal \n
    if ( /\s/ )
    {   #white space in path name implies error text
	s/^sh: +//;		#strip off any "sh:" leader
	print STDERR "$MyName: CAN NOT SELECT \"$dir\": $_\n";
	return undef;
    }

    return $_;
}


########################################################################
#
#   Initialize  --  Initialize operations
#	# &Initialize( localName, getOptArgs )
#	# if -c (csh) mode, define command line information.
#	# return value undefined.
#	# defines global pwd to current working directory.
#
sub Initialize
{   #general initialization
    local( $localName, $getOptArg ) = @_;

    if ( grep /^--help$/, @ARGV )
    {   # --help processing (must research --help under perl4)
	print "$localName ";
	local($hyphen) = " -";		#start with hyphen
	while ( $getOptArg )
	{
	    last unless $getOptArg =~ s/^([^:])(:?)//;	#pick off an argument
	    local($switch, $colon) = ( $1, $2 );
	    print $hyphen if defined $hyphen;
	    $hyphen = undef;
	    print $switch;
	    if ( $colon )
	    {   #argument expected
		print " xxx";
		$hyphen = " -";
	    }
	}

	print "\n";

	print "    use \`man pd\` or \`man pushd\` for help.\n";
	print "    (fail-safe: `pushd.pl +Man | nroff -man | more -s\`,\n";
	print "     or look at opening comments of source file)\n";

	exit 0;
    }

    &Getopts( $getOptArg );		#call Getopts with appropriate args

    $opt_L = 0 if $opt_P;	#-L is exclusive of -P (and vice versa)
    $opt_L = $opt_L ? " -L" : undef;	#make very nice values
    $opt_P = $opt_P ? " -P" : undef;	##for testing and shells

    $opt_LP = $opt_L		#what type of -L or -P we have, undef if none
    		? $opt_L
		: ( $opt_P ? $opt_P : undef );

    ##################################################

    $Pwd = &pushdPwd(".") 		#get current dir with proper -LP
	    || die "serious pushdPwd bug. stopped";	
		## NOTE: if -P or -L is active, it may indicate either
		## `cd` or `pwd` DOES NOT SUPPORT -LP. In this case
		## use of -L and -P must be removed from all usage's,
		## including within the profile.

    $nextOLDPWD =	#define OLDPWD to previous cd (e.g., current PWD).
    		"";	#   SILLY ME: rely on native `cd` to set OLDPWD!
#	    ( ! $opt_c  &&  ( defined $opt_LP  ||  defined $OLDPWD ) )
#		? ( " && export OLDPWD='$Pwd'" )
#    		: "";
#			# NOTE: only newer Borne shells (ksh/bash) have this 
#			# feature, and they also have the -L and -P switches.
#			# therefore we use -LP switch to ASSUME OLDPWD is
#			# needed. Fairly harmless if this is not the case.

    ## prefix (PUSHD1) and suffix (PUSHD2) set for -c "prompt=" stuff
    if ( $opt_p )
    {   #doing command-line prompts
	$Prompt1 = defined( $ENV{"PUSHD1"} ) ? $ENV{"PUSHD1"} : "";
	$Prompt2 = defined( $ENV{"PUSHD2"} ) ? $ENV{"PUSHD2"} : "% ";
    }

    #### now we get around to doing the CSH specific stuff
    if ( $opt_c )
    {   #this IS a C-shell
	$opt_c = $UnCshAlias;
    }
    else
    {   #pasta shell: normal cooking techniques
	$opt_c = "";
    }
}


########################################################################
#
#   ReduceStack -- trash duplicate entries in the stack
#	# @NewStack = &ReduceStack( @OldStack );
#	# deletes duplicate entries from existing stack.
#	# deletions only occur my name: links will spoof.
#
sub ReduceStack
{
    local(@DirList) = @_;	#get working COPY of directory stack

    local(%Dirs) = ();		#for checking duplicate entries

    local($d) = 0;
    while( $d < @DirList )
    {   #while we have directories yet to be looked at in the stack
	local($Dir) = $DirList[$d];	#get a directory entry
	local($DirTmp) = $Dir;		#working copy we can mangle
	$DirTmp =~ s"^\~/"${HOME}/";
	if ( defined( $Dirs{$DirTmp} )  ||
		! -d $DirTmp  ||  ! -x $DirTmp  ||  ! -r _ )
	{   #directory already exists or is invalid: wipe from stack
	    splice( @DirList, $d, 1 );	#remove this entry from @DirList
	    next;			#try new entry at this position
	    				## WITHOUT INCREMENTING $d
	}

	$Dirs{$DirTmp} = 1;		#remember we have seen this

	$d++;			#this is OK: advance to next entry
    }

    return( @DirList );		#return directory list
}


########################################################################
#
#   RotateStack() - symbolically rotate (or raise) stack for "pd =*" 
#	# &RotateStack( $DirToFind )
#	# returns stack depth, in form of +n, to selected element
#	# exits with error message on fatal errors.
#
sub RotateStack
{
    local($Dir) = $Dir;

    $Target = $Dir;
    $Target =~ s/^=//;		#delete leading '=' we no longer want or need
    $Target =~ s/^\s*//;	#wipe leading and trailing spaces in
    $Target =~ s/\s*//;		##command line arguments.
    if ( @ARGV )
    {
	print STDERR "pd: TOO MANY DIRECTORY NAMES: ", join(",", @ARGV ), "\n";
    }

    print STDERR "&Target=$Target\n" if $opt_z;

    if ( $Target =~ /^\s*$/ )
    {
	print STDERR "pd: INVALID USE OF \"=\": argument after \"=\" required\n";
	exit(1);
    }

    $Dir = &SearchStack( 1, $Target );		    #try for favored match

    $Dir = &SearchStack( 0, $Target ) unless $Dir;  #be more sloppy, if needed

    print "+$Dir\n" if $opt_z;

    return $Dir if $Dir;		#return directory to 

    #### CAN NOT MAKE ANYTHING OF IT ####
    print STDERR "$MyName: NOTHING LIKE $Target IN STACK\n";
    for ( $n = 0; $n < @Dirs; $n++ )
    {
	printf( STDERR "%5d: %s\n", $n+1, $Dirs[$n] );
    }

    print $STDSHELL "false\n"; #force shell function to return error to caller

    exit(1);

}


########################################################################
#
#   SearchStack - try to find a "best match" for the string
#	# $Dir = &SearchStack( $searchTopLevelSw )
#
sub SearchStack
{
    local($n1) = shift( @_ );  #normally called with 1 first, then 0 on failure.
    			#  1: do NOT search the current top level of the stack.
			#     the idea being we want to AVOID matching with
			#     the top dir (which is the current dir) if at
			#     all possible.
			#  0: search the current top level of the stack.
			#     the idea being we want to match with the top
			#     (current directory) if that is the only thing
			#     that matches.
    local($Target) = shift( @_ );	#target directory
    local($TargetRe) = quotemeta( $Target );	#value ready for reg. exprs.

    local($Dir) = undef;	#return value (have yet to f ind)

    local($n);			#current stack level being examined
    local($nbias) = 0;		#constant of zero (forgot what this used to be!)

    local(@Dirs2) = ( $Pwd, @Dirs );	#make directory list WITH current dir
    					##at top of stack.

    ##### FIRST TRY FOR A COMPLETE AND EXACT MATCH OF THE NAME #####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir eq $Target )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### TRY FOR EXACT TAIL MATCH #####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ m"/$TargetRe$" )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### TRY FOR LOOSER TAIL MATCH: head of tail #####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ m"/$TargetRe[^/]+$" )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### TRY FOR EVEN LOOSER TAIL MATCH: head of tail #####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ m"/[^/]+$TargetRe$" )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### TRY FOR LOOSER TAIL MATCH: anywhere within tail #####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ m"$TargetRe[^/]+$" )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### TRY FOR ANY OLD TAIL MATCH: any tail match #####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ m"/[^/]*$TargetRe[^/]*" )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### TRY FOR A HEAD MATCH: true head #####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ m"^$TargetRe/" )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### TRY FOR A HEAD MATCH: true tail #####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ m"^[^/]+$TargetRe/" )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### TRY FOR WORD BREAK (e.g., quoted by \b breaks) ####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ /\b$TargetRe\b$/ )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    ####################################################################

    #### TRY FOR NAME /ANY MATCH/ #####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ m"/$TargetRe/" )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### TRY FOR ANY OLD THING ####
    for ( $n = $n1; $n < @Dirs2; $n++ )
    {
	$Dir = $Dirs2[$n];
	if ( $Dir =~ /$TargetRe/ )
	{
	    $n += $nbias;
	    $Dir = "+$n";
	    return $Dir;
	}
    }

    #### LAST TRY: GO FOR ANY OLD THING WITHOUT REGARD TO CASE ####
    if ( $n1 == 0 )
    {   #only try this when we are desperately seeking something
	for ( $n = $n1; $n < @Dirs2; $n++ )
	{
	    $Dir = $Dirs2[$n];
	    if ( $Dir =~ /$TargetRe/i )
	    {
		$n += $nbias;
		$Dir = "+$n";
		return $Dir
	    }
	}
    }

    $Dir = undef;		#did not match anything

    return $Dir;
}


########################################################################
#
#   ShowStack - return value, including quotes, for defining
#	a new PUSHD environment variable to hand off to the shell.
#
sub ShowStack
{
    local(@Stack) = $opt_x
    	?  &ReduceStack( @_ )		#simplify stack
	:  @_;				#keep raw stack

    if ( $opt_t )
    {
	local($n);
	for ( $n = 0; $n < @Stack; $n++ )
	{   #run tilde conversions on everyone
	    $Stack[$n] = &Tilde( $Stack[$n] );
	}

    }

    local($s) = $opt_c ? "setenv PUSHD " : "PUSHD=";
    local($t) = $opt_c ? ""              : " &&  export PUSHD";

    return( "$s'" . $dirDelim . join( $dirDelim, @Stack ) . "'$t" );
    		#return MODERN style names
}


########################################################################
#
#   Tilde - convert path name to any appropriate tilde prefix
#
sub Tilde
{
    local($_) = shift @_;

    $_ = '~' if $_ eq $HOME;	#allow for home dir all by itself
    s"^$HOME/"~/";		#home directory becomes simply ~/

    return $_;
}



## mark




__END__
.\"       _____                  __________                        
.\"      /     \ _____    ____   \______   \_____     ____   ____  
.\"     /  \ /  \\__  \  /    \   |     ___/\__  \   / ___\_/ __ \ 
.\"    /    Y    \/ __ \|   |  \  |    |     / __ \_/ /_/  >  ___/ 
.\"    \____|__  (____  /___|  /  |____|    (____  /\___  / \___  >
.\"            \/     \/     \/                  \//_____/      \/ 
.\"
.
.TH pushd.pl 1 \*(7d "Mad Programmer Software" "Free Software"
.SH NAME
pushd, pd, popd, dirs \- pushd.pl provides standard pushd, popd and dirs directory stacks to 
shells that do not support them and
enhanced functionality to shells that do.
.
.SH SYNOPSIS
.LP
\0\fBpushd\fP [\fB\-LPrsSx\fP] [+\fIn\fP | \fIpath\fP [ | \fB=\fP\fIpath\fP] ]
.br
\0\fBpushd\fP [\fB\-LP\fP] \fIold\fP \fInew\fP [ \fIold2\fP \fPnew2\fP ... ]
.br
\0\fBpd\fP [\fB\-LPrsSx\fP] [\fB=\fP\fIpath\fP | \fB+\fP\fIn\fP | \fIpath\fP]
.br
\0\fBpd\fP [\fB\-LP\fP] \fIold\fP \fInew\fP [ \fIold2\fP \fPnew2\fP ... ]
.br
\0\fBpopd\fP [\fB\-sSx\fP] 
.br
\0\fBdirs\fP [\fB\-1Sx\fP] 
.br
\0\fBpushd.pl \+Man\fP
.
.
.SH DESCRIPTION
This family of commands provides a friendly way of
selecting, and reselecting, directories from shell commands.
Previously "pushed" directories are remembered in a directory stack
allowing them to be quickly reselected by stack position number
\fI\&or by symbolic names using a fragment of a name in the stack\fP.
Stacks may also be preloaded with frequently used directories.
.LP
The \fB\&pushd.pl\fP family provide enhancements and extensions over
directory stacks built into typical shells.
They may be used with older shells that do not support native stack operations
or replace existing stack commands with more useful commands.
.LP
Users do not directly use \fB\&pushd.pl\fP but rather use
functions, or aliases, set up during shell initialization.
These aliases are used as normal shell commands.
See PROFILE for typical setups.
Internally new directories are selected with the shell's built in
\fBcd\fP command.
.LP
Full details on this family of commands are found here.
A shorter, more general user level text, is available at some sites in the
\fBpd\fP(1) manual page.
.
.LP
Available user commands follow:
.LP
.ti -\w'\0'u
\fBpushd\fP | \fBpd\fP
.br
\fBpushd\fP and \fBpd\fP select a new directory as \fBcd\fP(1) does.
The current directory is pushd onto a directory stack
before selecting a new directory.
If no arguments are provided,
the top two entries in the stack are exchanged.
.LP
The name of the new directory is printed to standard out unless
the \fB-s\fP option is used.
Typically only interactive shells would print names.
.LP
The differences between \fBpushd\fP and \fBpd\fP are subject
to local configuration.
Typically \fB\&pd\fP "rises" the stack... pulls the requested directory
to the top without rotating the stack;
the order of the other directories remain unchanged
(see \fB\-r\fP option).
\fB\&pushd\fP typically rotates the stack in a more classic manner.
Further \fB\&pd\fP tends to remove problem directories from the stack
(see \fB\-x\fP option).
See appropriate OPTIONS for all possible differences.
.LP
.ti -\w'\0'u
\fBpopd\fP
.br
\fBpopd\fP pops the top directory from the directory stack to
return to the previous directory.
The name of the original current directory is lost.
.LP
The name of the new directory is printed to standard out unless
the \fB-s\fP option is used.
.LP
.ti -\w'\0'u
\fBdirs\fP
.br
\fBdirs\fP lists the current entries in the stack,
starting with the current directory.
.LP
.ti -\w'\0'u
\fBpushd.pl\fP
.br
\fBpushd.pl\fP is intended for direct use by people installing the associated manual
page on the system.
This page should be properly installed in the local user manual pages.
.
.
.SH OPTIONS
.IP "\0\0+\fI\&n\fP" \w'\0\0\0MM'u
\fBpushd pd\fP:
.br
Rotates the stack the specified number of levels.
Zero requests no rotation (stack remains unchanged).
.IP
This numeric rotate feature becomes less useful the deeper the stack
as you have to know the depth of the desired entry in the stack.
See the \fB=\fP option for 
selecting existing stack members symbolically.
.IP
NOTE: 
Shells with built-in \fBpushd\fP commands rarely support "0" as a valid count.
Avoid "0" in scripts if you want to be 
portable to built-in directory stack commands.
.
.IP "\0\0\-1\fP"
Force dirs to only list one directory per-line.
.
.IP "\0\0\-r\fP"
\fBpushd pd\fP:
.br
Rise name/Reorder stack.
Any "+" and "=" rotations are not to rotate the stack.
The specified directory is to be moved from its current position to
become the new top-level directory.
.IP
The hole is closed up and
any remaining entries in the stack retain their original order.
.
.IP "\0\0\-s\fP"
\fBpopd pushd pd\fP:
.br
Silence.
Do not print the new current directory after it is selected.
.
.IP "\0\0\-S\fP"
\fBdirs popd pushd pd\fP:
.br
Sort stack after any new directory has been selected.
All stack entries, but the current directory, 
are sorted in simple alphabetical order.
.IP
On \fBdirs\fP commands, only the printed stack is affected.
.
.IP "\0\0\-x\fP"
Duplicate or unselectable directory names are removed from the stack.
On \fBdirs\fP commands, only the printed stack is affected.
.IP
The current directory is not always considered during duplicate entry removal.
This is not a bug, but a feature.
.
.IP "\0\0=\fI\&path\fP"
\fB\&pd\fP and \fB\&pushd\fP:
.br
Name of directory already in the stack, or a fragment of that name. 
Allows users to return to previously "pushed" directories
by name rather than rotation numbers. 
Any sufficiently unique name fragment should work.
\fBpd\fP searches the stack using a "best match" algorithm.
If the name fragment is too ambiguous, the first best match is used.
.IP
The stack is rotated by the appropriate number of elements to select the
requested directory.
Internally the \fB=\fP request is converted to a \fB+\fP request and \fB+\fP
performs the actual stack rotation.
If the wrong directory is selected due to an ambiguous path,
repeating \fBpushd\fP commands should eventually find the desired directory
while
repeating \fB\&pd\fP commands tends to toggle between two wrong directories.
.IP
The top-level directory (current directory) is not reselected unless
it is the only possible match.
.
.IP "\0\0\fIpath\fP"
\fBpushd pd\fP:
.br
Name of directory to be selected.
If no directory is provided,
the first two entries on the stack are exchanged.
.IP
If \fIpath\fP is a single hyphen character (\fB-\fP) and several
conditions are met, the environment variable OLDPWD is expected to contain
the directory to be selected.
After a successful select OLDPWD is updated to contain what was
the current directory (e.g., $PWD) when the command was started.
This is feature allows compatibility with newer \fBksh\fP and \fBbash\fP
shells allowing their \fBcd\fP 
commands to seamlessly work with this suite.
.
.
.IP "\0\0\fInew old\fP"
\fBpushd pd\fP:
.br
Mimics the two argument \fBcd\fP command of \fBksh\fP
to change the current directory.
.IP
The current directory path is examined for a character string 
containing \fI\&new\fP.
The first occurrence of this string is replaced by \fIold\fP and
that directory is selected.
The stack is not popped and the '=' symbolic character is not effective.
.IP
The two-argument option is available to all users
regardless of how this push suite is configured or 
the shell being used.
.
.IP "\0\0\+Man\fP"
\fBpushd.pl\fP:
Prints an unformatted man page
for the program.
Pipe into the appropriate *roff program to format it.
.IP
.RS
\fB\0\0pushd.pl \+Man | nroff \-man | more \-s\fP
.RE
.IP
Administrators may also install unformatted man pages:
.LP
.RS
\fB\0\0\fBcd \fP\fI/usr/local/man/man1\fP
.br
\fB\0\0pushd.pl \+Man >pushd.pl.1\fP
.br
.RE
.IP
NOTE: install under \fBpushd.pl.1\fP to not only be consistent,
but avoid confusion with \fBpushd\fP(1) for \fBcsh\fP(1).
.
.
.
.SH SPECIAL OPTIONS
.LP
The following options are not intended for use on 
regular command lines. As such they are not in the previous SYNOPSIS section.
They are only for use within the profile's function definitions
(e.g., "\fBpd() { eval `pushd.pl \+Pd \-t $*;`; }\fP").
Users are free to put any \- options within their definitions.
.
.IP "\0\0\-c\fP"
\fBpopd pushd pd\fP:
.br
\fBcsh\fP shell.
Must set this if running under C shells.
.
.IP "\0\0\-L\fP"
Logical paths. See \fB\-P\fP for details.
.IP "\0\0\-P\fP"
\fBpushd pd popd\fP:
.br
Physical paths.
When the user's shell \fBpushd\fP
\fI\&as well as the local \fP\fBpwd\fP\fI command,\fP
support the \fB\-L\fP and \fB\-P\fP options,
then the favored value needs to be selected for \fBpushd\fP operations.
\fBpushd\fP was designed for \fB\-P\fP operations so that is suggested.
If omitted,
it uses the shell's default, which tends to be \fB\-L\fP on new shells.
.IP
\fB\-L\fP causes \fBcd\fP to treat symbolic links as physical paths when
setting \fB$PWD\fP.
Use of \fB\-P\fP causes \fBcd\fP to resolve symbolic links into the 
true physical path when setting \fB$PWD\fP.
.IP
NOTE: POSIX.2 compliant \fB\&pwd\fP commands \fIdo not support \-LP\fP.
.
.IP "\0\0\-p\fP"
\fBpopd pushd pd\fP:
.br
Put path name into prompt.
Only intended for older shells that do not have a way to automatically
place the name of the current directory into the shell prompt
(e.g., \fBsh\fP and \fBcsh\fP).
.IP
The PUSHD1 environment variable contains a prefix to place before
the path name (e.g., "", "\fB`hostname`:\fP", "\fB${LOGNAME}@`hostname`\fP").
The PUSHD2 environment variable contains the suffix,
typically 
"\fB$\0\fP" for Bourne based shells and
"\fB%\0\fP" for C shells.
.IP
Use of \fB\-p\fP requires an alias to \fBcd\fP so \fBcd\fP also
sets the prompt.
Other directory commands may also need to set the prompt.
.IP
NOTE: \fBcsh\fP likes to core dump under some OSs when 
trying to set the prompt to current directories.... 
the hard part may be finding a way to avoid the core dumps
(e.g., try \fBset prompt = `cd /tmp; pwd`\fP, 
and I really don't want to hear about 
which OSs like to core dump and which don't!).
.
.
.IP "\0\0\-t\fP"
\fBpd pushd popd\fP:
.br
Tilde shell.
Define if the local shell supports "~" to refer to the users home directory.
If the head of a stack entry matches the HOME environment variable,
a "~" replaces the home directory name.
Used to shorten paths, making them easier to read.
.
.
.
.SH PROFILE
.SH \0\0General Notes
The HISTORICIAL profile was the first profile,
and it was rather basic.
It was found that it was much more practical to have both 
\fBpushd\fP and
\fBpd\fP support \fB=\fP symbolic stack searches.
The main difference between the latest \fBpd\fP and \fBpushd\fP is that
\fBpd\fP raises the stack while \fPpushd\fP rotates the stack.
\fBpd\fP is also more aggressive at cleaning junk out of the stack.
.LP
The practical results is \fBpd\fP is generally the operation of choice,
but if the wrong directory has been fetched from a deep stack 
repeated use of \fBpushd\fP allows users to
step through the stack until the desired 
directory is found. 
Repeated use of \fBpd\fP simply toggles between two wrong directories
while \fBpushd\fP steps through all matching directories.
.
.SH \0\0Bourne Shell Family
A series of shell function declarations in the shell start up file 
provides the proper aliases to pushd.pl.
This is best done in the "per-shell" file (e.g., 
\fB.shrc\fP, 
\fB.kshrc\fP, 
\fB.bashrc\fP):
.LP
.nf
    if [ "${PUSHD:-not defined;}" = "not defined;" ]; then
        # in case "home" directory is symbolic link, \c
.if n \{\

        # ##\c
.\}
chase down real home directory
        PUSHD=`pwd` && cd -P && HOME=`pwd` && export HOME
        cd $PUSHD; 

        #Initialize stack to values: use "" for empty stack.
        PUSHD="
            ~/typical/directory
            /usr/local/lib/perl5/site_perl/5.005/LWP
            /usr/local/lib/perl5/5.6.1/CGI
              ... replace with directory list of your choice ...    
		";
        export PUSHD;
     fi
    pushd_s=s;		#suppose "silent" batch shell
    if [ ."${PS1:-not-defined}" != ."not-defined" ];
      then
        pushd_s=;	 #interactive shells show dir
      fi
    dirs()  { pushd.pl +Dirs \-t $*; }
    pushd() { eval `pushd.pl +Pd -Pt$pushd_s $*;`; }
    pd()    { eval `pushd.pl +Pd -Ptrx$pushd_s $*;`; }
    popd()  { eval `pushd.pl \+Popd \-Pt$pushd_s $*;`; }
    unset pushd_s
.fi
.de &o
.LP
NOTE ON \fB\-P\fP: The \fB\-P\fP option must be omitted 
under either older shells or pwd programs that
do not support \fB\-L\fP and \fB\-P\fP options.
Such old shells may also require a \fB\-p\fP option if the 
new directory name is to appear in the command line prompt.
Users may change \fB\-P\fP to a \fB\-L\fP 
under any shell
if that is favored.
..
.&o
.
.
.SH \0\0C Shell Family
Unfortunately the original C shells (\fBcsh\fP) were particularly resistant to 
features needed to make this work.
Thankfully the newer \fBtcsh\fP shell does better.
The following indented
note applies only if you are stuck with genuine original \fBcsh\fP shells.
Users of \fBtsch\fP should have no problems using the provided code.
.RS
.LP
Original \fB\&csh\fP restrictions:
.br
Using \fBpushd.pl\fP to replace \fBcsh\fP's native \fBpushd\fP family
may work under your \fBcsh\fP with the following set up in \fB.cshrc\fP.
It relies on having \fIsome way\fP to tell \fBcsh\fP that a \fBcd\fP command
in the middle of an alias
is to run as itself instead of a recursive \fBcd\fP alias.
as used within \fBpushd.pl\fP's \fBCsh\fP subroutine.
"\fBrepeat 1 cd\fP" has been found to do this on \fBcsh\fP's currently
available to the author (see \fB$UnCshAlias\fB within \fBpushd.pl\fP if you
need to change this).
Good luck on your \fBcsh\fP.
.LP
NOTE:
Once upon a time \fBcsh\fP used to accept "\fB\ecd\fP" to force
the internal \fBcd\fP command,
but this now fails on various \fBcsh\fP shells
the author has access to.  
Original \fBcsh\fP shells may still accept it.
.RE
.LP
Sample profile:
.nf
    if ( $?prompt ) then
    # {
      if ( $prompt != "" ) then
      # {  interactive shell: set aliases
        setenv PUSHD1 "`hostname`:"
        setenv PUSHD2 '% '

	    ###### ONLY NEEDED ON VERY OLD SHELLS WITHOUT -P
	    #just in case HOME contains some symbolic link to
	    ##our physical home directory, resolve to physical
            set tmp = `pwd`
            cd -P
            setenv HOME `pwd` 
            cd $tmp; 
            unset tmp

	    ## set default PUSHD for login shell
	    if ( ! $?PUSHD ) then
		setenv PUSHD ""
	      endif

        set dol = '$';
        alias cd 'cd \e!* && set prompt="$PUSHD1"`pwd | sed\c
.if n \{\
.br
\0\0\0\c
.\}
\-e "s.^${HOME}${dol}.~." \-e "s.^${HOME}/.~/."`"$PUSHD2"'
        cd -P .

	set pushd_s = "s";	#suppose silent batch shell
	if ( $?prompt ) set pushd_s = "";	#noisy interactive
        alias dirs     'pushd.pl +Dirs \-ct \e!*;;'
        alias pushd    'eval `pushd.pl \-cPtx$pushd_s \e!*;`;'
        alias pd       'eval `pushd.pl +Pd \-cPrtx$pushd_s \e!*;`;'
        alias popd     'eval `pushd.pl +Popd \-cPt$pushd_s \e!*;`;'
	unset pushd_s;		#delete temporary variable
      # }
        endif
    # }
      endif
.fi
.if n \{\
.LP
NOTE:
In the above code,  the "alias cd" needs to be on a single line.
In this example the "sed" command has a line break forced as se\fB\en\fPd
so the line fits on the page.
.&o
.\}
.
.
.SH HISTORICAL PROFILE
.LP
The following is a bit more conservative version of the profile 
that does not "rise" the stack.
While this was the originally suggested profile,
and some of the documentation in this  manual page is written as if this
historical profile is still used,
experience has found the more feature rich defaults 
in the PROFILE section tend to be more useful. 
This alternate remains documented for historical purposes.
.LP
.nf
pushd() { eval `pushd.pl \-Pt $*;`; }
pd()    { eval `pushd.pl \+Pd \-Pt $*;`; }
.fi
.LP
This changes the difference between \fBpushd\fP and \fBpd\fP from 
"=" support (under this alternate only pd supports "=") and
deletes \fB\-rx\fP options from \fBpd\fP and \fBpushd\fP.
Experience has shown \fB\-rx\fP can be very useful with very deep stacks
so they are now the default.
.LP
\fBcsh\fP users would need to change their profile to select similar options.
.
.
.
.SH SEE ALSO
\fBpushd\fP(1), \fBpopd\fP(1), \fBdirs\fP(1) built-in shell commands.
\fBperl\fP(1), 
\fBsh\fP(1),
\fBbash\fP(1),
\fBcsh\fP(1),
\fBksh\fP(1)
.
.
.
.SH ENVIRONMENT
.SH \0\0CDPATH
The environment variable CDPATH is used 
when new relative directories cannot be found during push operations.
If defined,
CDPATH is expected to contain a list of colon (:) separated
directory names.
If the requested directory is not found in the current directory
push operations search for the requested directory relative 
to the directories in CDPATH.
The first directory found by this search is selected.
Using "../\fIxyz\fP" can often be used to select directory \fIxyz\fP
 in CDPATH.
.LP
RESTRICTION:
Directory names in CDPATH should start with "/" to make them
absolute path names as relative path names can be very unpredictable.
.
.SH \0\0OLDPWD
Some shells set OLDPWD to 
what the current directory was (e.g., $PWD) \fIbefore\fP
any directory change.
If $OLDPWD is defined
this pushd suite honors this variable in traditional ways
but relies on native \fBcd\fP(1) commands to set it.
.
.SH \0\0PUSHD
The information on the current stack is kept in the environment variable PUSHD.
Stack entries are recorded left to right (top to bottom).
.LP
If the first character of the stack is a colon then the stack contains
colon delimited names. All embedded white space is significant.
.LP
Else for historic purposes stack entries are delimited by any use of
spaces or colons. Historically spaces were used.
.LP
Child processes inherit PUSHD as with any other environment variable.
No information is cached to disk.
Only previously pushed directory names are recorded in this stack.
The top level of the logical stack is the current directory,
which is not recorded in PUSHD.
.
.SH \0\0PUSHD1 and PUSHD2
The PUSHD1 and PUSHD2 environment variables are used under \fB\-p\fP.
See SPECIAL OPTIONS.
.
.
.SH DIAGNOSTICS
All severe error messages printed by \fBpushd.pl\fP appear in all upper case 
letters to make them easier to spot in lot files.
Such are always written to standard error.
.LP
Errors in selecting the directory come from the \fBcd\fP command
\fBpushd.pl\fP used to select the directory.
Bad pushes should not change the directory stack.
Bad pops should clear the problem entry from the stack.
.
.
.
.SH RESTRICTIONS
In case of excessive stack growth, 
these commands may start to fail if the length of all entries in the stack 
approaches the maximum command length supported by the shell.
This has never been a problem for the author despite some deep stacks.
.LP
May not work from older "C" shells (see \fBcsh\fP notes in PROFILE).
.LP
Spaces are not allowed to be actual characters in directory names
unless new format PUSHD are used (e.g., leading colon in value).
Any old format PUSHD settings are converted to new format on their first use.
.
.
.
.SH INSTALLATION
.SH \0\0\0Global Usage
System administrators may not want to make this available to
all users as it is likely to cause problems to shell scripts
that expect the original pushd/popd operations.
Further, shells that do not have a system wide "per shell" 
configuration file cannot be properly configured to use these programs
on a global base.
However, if you want to give it a try anyway...
.LP
System administrators may make these features available to all users
of shell commands by creating a file for each family of shells used
on the system (e.g., Borne Shell vs. C shell) that is valid for all
members of a particular shell family (pushd.sh for Bourne shells
and pushd.csh for C shells).
The file should be read each time a new shell is started up
from the shells start up file.
Reading the file only at login will not do what is needed.
The file must not be executable.
.
.LP
In addition to installing \fBpushd.pl\fP on a location shared by all
users (/user/local/bin/pushd.pl is suggested as a standard location,
providing that works on your system) a man page should be installed.
.LP
\0\0\0pushd.pl +Man >/usr/share/man/man1/pushd.pl.1
.LP
It is important 1) not to overwrite any existing \fBpushd\fP(1) manual page
note how we use pl in our man page file name), and
2) run whatever command is needed to add \fBpushd.pl.1\fP to the \fB\&whatis\fP index
(see \fBwhatis\fP(1), or perhaps another command).
.
.
.SH \0\0\0Individual Users
Individual users can add the appropriate commands to
the configuration file for their shell that is read
each time a new shell is started up.
Note how the suggested PROFILE ensures \fB\-s\fP (silence) is set
if the shell is not interactive.
.LP
Users using multiple shells may wish to
use a personal version of the techniques described in Global Usage.
.LP
Note that individual users may preload PUSHD with any desired list
of directories popular to the current user.
This is a big advantage to allowing individual users to decide if, 
and how,
to use this new pushd.
.
.
.SH BUGS
Genuine Bourne shell (\fBsh\fP(1)) users may find they can't use \fBpushd.pl\fP
in any but the login shell.
This is a restriction of \fBsh\fP itself as \fB.profile\fP is only run at
login and \fB.shrc\fP type files for each shell are not supported.
All other shells should be OK if they have an "each shell" start up file you can
put the function definitions in.
See your shell's manual page.
.
.
.
.SH REQUIREMENTS
Requires at least perl 4 (maybe 5 by now).
.
.
.SH NOTES
While you may think of the stack as the current directory followed by all
previously pushed directories,
the PUSHD environment variable does not contain the current directory.
.LP\" tightly bind previous and following paragraphs together
Users may issue simple \fBcd\fP(1) commands without affecting the 
"pushed" stack in PUSHD.
.LP
Normally the current shell will inherit 
the stack of any ancestral shell that was
also using \fBpushd.pl\fP.
The descendent can not modify any stack put its own (see ENVIRONMENT).
.LP
Totally replaces the previous, and fairly lame, \fBpd.pl\fP program.
.LP
A lamer version of \fBPUSHD.EXE\fP
was available for users of MS-DOS shells.
It may still be, but it is not supported at this time and based on C code.
.
.
.
.SH AUTHOR
Gilbert Healton <\fB\&ghealton@exit109.com\fP>.
.br
\fB\&http://www.exit109.com/~ghealton/\fP, or search the web for 
the exact phrases
"Gilbert Healton" or "Original Mad Programmer"(TM).
.
.
.SH DISCLAIMER
Software subject to change without notice.
Though much effort was made to keep documentation accurate,
no guarantee is made that documentation is accurate.
.LP
By using this program or documentation you accept and agree to the terms and
conditions printed below. 
If you do not agree \fIdo not use the program.\fP
.
.
.SH LICENSE INFORMATION
This version of the software is released under the perl Artistic license
(visit
http://www.perl.com/pub/a/language/misc/Artistic.html 
for details).
.LP
Some early and much cruder versions of \fBpushd\fP were released in the
Public Domain.
Thus only the changes to the last PD version are covered by the license
and copyright.
However as these changes were very extensive 
and not flagged within the source file 
the practical result is the entire program,
including documentation,
is covered by the license.
.LP
\*(7c
.
.
.SH REVISION INFORMATION
\*(7i
.
.
.
.\"    #end: pushd.pl
__END__

