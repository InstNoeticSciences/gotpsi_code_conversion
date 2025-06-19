#!/usr/bin/perl -w

use CGI qw(:standard);
use CGI::Carp qw/fatalsToBrowser/;
require "OLEinit.pl";
require "OLEutils.pl";
require "OLEmath.pl";
require "OLErand.pl";
require "OLEerr.pl";

$nstages = 32;				# num of Markov chain stages

						# message to send
#@mess = (0,0,0,0,0);				# 0 (this means all output bits = 1, i.e. the original version)
@mess = (18,5,20,18,15);			# "retro"
#@mess = (16,5,1,3,5);				# "peace"

unless ($trperrun = param('trperrun')) { $trperrun = 10; }	# number of trials in a run
unless ($tarims = param('tarims')) { $tarims = 4001; }	# 40 tars, first tar index 1

my $timeval = localtime(time);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
++$mon; $year += 1900;
$ymd = sprintf("%02d%02d%02d", $year-2000, $mon, $mday);
$logfilename = "$CardDDataDir/cardD$ymd.dat";

						# get params
my $userid = checkID();
my $trialnum = cookie(-name=>'cardDtrialnum');	# cur trial num
my $bits = cookie(-name=>'cardDbits');		# cur cardbits, cardhits<<5
my $cardhits = ($bits>>5) & 0x1f; 			# 5 bits - cards done
my $cardbits = $bits & 0x1f;				# 5 bits - cards hit

my $runhits = param('runhits');		# num hits in this run
my $hitimage = param('hitimage');		# pic to display on hit

if (!defined($bits) || !defined($runhits) || !defined($trialnum) ||
		countb($cardhits) > countb($cardbits) || $runhits > 5*$trialnum) {
	SeqErr("cardDlog0: $trialnum, $runhits, $cardbits, $cardhits");	# sequence error
	exit(0);
}

						# which card was clicked
if    (defined(param('card0.x'))) { $cardnum = 0; }
elsif (defined(param('card1.x'))) { $cardnum = 1; }
elsif (defined(param('card2.x'))) { $cardnum = 2; }
elsif (defined(param('card3.x'))) { $cardnum = 3; }
elsif (defined(param('card4.x'))) { $cardnum = 4; }
else {
	SeqErr("cardDlog1: $trialnum, $cardbits");		# error
	exit(0);
}

if ($cardbits & 2**$cardnum) {	# card already done (reload)
	SeqErr("cardDlog2: $trialnum, $cardbits, $cardnum");	# sequence error
	exit(0);
}
else { $cardbits |= 2**$cardnum; }	# bit for card done

						# randomly choose the result for this card (Markov chain)
my ($d_s, $d_t);
($Mn, $Mi, $Mk) = ($nstages, $nstages-1, 2);	# n stages, output bit i, 1/2**k prob flip at each stage

$Mbits0 = getMarkbits($Mn, $Mk);	# get the main chain bits 0..Mn-1
$resb = ($Mbits0>>$Mi)&1;		# result bit: output of i'th stage
$tarb = getmessbit($trialnum,$cardnum);	# the desired message bit
$hit = ($resb==$tarb) ? 1 : 0;	# a hit if the result matches the target bit 
if ($hit) { ++$runhits; $cardhits |= 1<<$cardnum; }

$Mbits1 = getMarkbits($Mn, $Mk);	# get the control chain bits, recorded but not used

#$imdir = "../images2/";		# card images to use
$imback = "cback5.jpg"; $imhit = $hitimage; $immiss = "cmiss.jpg";
$imcard = $hit ? $imhit : $immiss;

						# log the step
$ccb = countb($cardbits); $cch = countb($cardhits); 
open  LOGFILE,">>$logfilename";
flock (LOGFILE, 2);
$tarb ^= 1;			# complement since tarb field is 0 in all prev recorded trials, yet target was 1
				# nota bene: format change - separate Mbits1 field added 6/22/06 
#print LOGFILE "$userid, $tarb, $ccb, $cch, $Mn, $Mi, $Mk, $Mbits1<<Mn|$Mbits0,";
print LOGFILE "$userid, $tarb, $ccb, $cch, $Mn, $Mi, $Mk, $Mbits0, $Mbits1,";
print LOGFILE " $cardnum, $hit, $runhits, $trialnum, $timeval, $hitimage,\n";
flock (LOGFILE, 8);
close LOGFILE;

						# display the page
$cookie = cookie( -name=>'cardDbits',
                   -value=>($cardhits<<5)|($cardbits&0x1f),
                   -path=>"/",
                   -expires=>'+1d');

print header(-cookie=>$cookie);
print start_html("Card Draw Test Result");
print<<EOF0;
<body bgcolor="#FFFFFF" text="#000080" link="#3333FF" alink="#0000CC" vlink="#333366">
<p><br><center><font color="#000080"><h1>Card Draw Test</h1></font></center>
EOF0

print "<center><b>User</b> $userid &nbsp&nbsp <b>Trial</b> $trialnum / $trperrun</center><br>\n";
print "<center>Make the target <a href=\"$Img2URL/$hitimage\">";
print "<img src=\"$Img2URL/$hitimage\" width=40 height=50></a> appear!&nbsp<p>\n";

print start_form("POST","cardDlog.pl");

						# display the cards
foreach $j (0..4) {
	if ($cardbits & (1<<$j)) { 	# done
		$c = ($cardhits & (1<<$j)) ? $imhit : $immiss; 
		print "<img src=$Img2URL/$c width=130 height=157>\n";
	} 
	else {
		print "<input type=\"image\" name=\"card$j\" src=$Img2URL/$imback width=130 height=157>\n";
	}
}

#print "</center><HR><center>\n";

print "<input type=\"hidden\" name=\"trperrun\" value=$trperrun>\n";
print "<input type=\"hidden\" name=\"tarims\" value=$tarims>\n";
print "<input type=\"hidden\" name=\"runhits\" value=$runhits>\n";
print "<input type=\"hidden\" name=\"hitimage\" value=$hitimage>\n";
print end_form(); print "\n";

#if (debug()) { printf($d_s.$d_s."\n", $Mbits0, $Mbits1); }	# debug

if ($hit) { print "<p>That's a <font color=\"#FF0000\">HIT!</font>"; } 
else { print "<p>Sorry, that was a miss"; }
print "&nbsp;&nbsp;--&nbsp;&nbsp;";
printf("%d out of %d", $cch, $ccb);
if ($ccb==5 && $cch==0) { print "&nbsp;&nbsp;--&nbsp;&nbsp;Yikes!"; }
if ($ccb==4 && $cch==4) { print "&nbsp;&nbsp;--&nbsp;&nbsp;Excellent!"; }
if ($ccb==5 && $cch==4) { print "&nbsp;&nbsp;--&nbsp;&nbsp;Good!"; }
if ($ccb==5 && $cch==5) { print "&nbsp;&nbsp;--&nbsp;&nbsp;Fantastic!"; }
print "\n";

if (countb($cardbits) < 5) {				# not all 5 cards done
	print "</center>\n";
}
else {							# all 5 cards done
	print "<p>Total $runhits hits in $trialnum trials, ";
	if ($trialnum > 0) { printf("hit rate = %.2f hits/trial", $runhits/$trialnum); }
	else { print("hit rate = ?"); }
	print "</center><p>\n";

	print start_form("POST","cardD.pl");

	if ($trialnum >= $trperrun) { 
		print "<blockquote><center>";
		print "End of run.  ";
		if ($runhits <= 2.5*$trialnum) {	# p = 1/2 each card
			print "Your results are at or below chance this time.\n";
		} 
		else {
			$odds = getbinomodds2($runhits, 5*$trialnum, 0.5);
			$odds_ = sprintf("%8.1f",$odds);
			print "The odds against chance of getting $runhits hits ";
			print "or more in $trialnum trials is about $odds_ to 1.\n";
			if ($odds > 50) { print "<br>Your results are outstanding!\n"; }
		} 
		print "</center></blockquote>";
	
		$runhits = 0;

		print "<center><p><input type=\"submit\" value=\"Next Run\" name=\"ok\"></center>\n";
		print "<ul><blockquote>";
		print "<li>Go to the <a href=\"cardDhof.pl\">Card Draw Test Hall of Fame</a></li>\n";
		print "<li>Restart the <a href=\"$HtmlURL/cardD.htm\">Card Draw Test</a></li>\n";
		printchoices();
		print "</ul></blockquote>";
	}
	else {
		print "<center><p><input type=\"submit\" value=\"Next Trial\" name=\"ok\"></center>\n";
		if (debug()) { print "<i><a href=\"cardDhof.pl\">Card Draw Test Hall of Fame</a></i><br>\n"; }
	}

	print "<input type=\"hidden\" name=\"trperrun\" value=$trperrun>\n";
	print "<input type=\"hidden\" name=\"tarims\" value=$tarims>\n";
	print "<input type=\"hidden\" name=\"runhits\" value=$runhits>\n";
	print end_form();
}

printsysmsg();		# system message
print end_html;

exit(0);

#################################


sub countb {		# count 1 bits in a byte
	my $b = $_[0];
	my $n = 0;

	foreach (1..8) { if ($b&1) { $n++; }; $b >>= 1; }
	return $n;
}

sub getMarkbits {		# get bits of a Markov chain
	my $n = $_[0];	# num stages
	my $k = $_[1];	# num flip bits (1/2**k prob of a flip at each stage)
	my ($t, $r) = (0, 0);		# flip bits, result bits

	my $m = (1<<$k)-1;			# 2**k-1 mask
	my $b = getrandint(2);			# rand bit, -1'th input to chain	#############
	my $r = $b&1;				# output bits, 0th is 50/50
	my $n1 = 0;					# num ones

	foreach my $i (1..$n-1) {		# chain of n XORs
		$t = getrandint(1<<$k);		# get flip bits
		if (($t&$m) == 0) { $b ^= 1; }	# each flip prob = 1/2**k
		$r |= $b << $i;			# i'th bit is output of i'th stage
		$n1 += $b;				# num ones
	}

	$d_s = "$n, $k, %0".$n."b<br>";	# debug print string

	return $r;
}

sub getmessbit {			# get message bit for trialnum (1-25) and cardnum (0-4)
	my $tn = $_[0];
	my $cn = $_[1];

	my $j = ($tn-1)%5;			# 5-letter message string, 5-10-25/trial runs
	my $b = ($mess[$j]>>$cn) & 1;		# get the bit
	return $b;
}

