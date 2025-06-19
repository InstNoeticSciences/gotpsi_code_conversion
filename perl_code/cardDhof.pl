#!/usr/bin/perl -w
						# Card Draw Test Hall of Fame
use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
require "OLEinit.pl";
require "OLEutils.pl";
require "OLEmath.pl";
require "OLEerr.pl";
require "cardDdata.pl";

$prog = "cardDhof";				# this program

# If we're running reports as root, then don't look for a user ID.
if ((defined $ENV{USER}) && ($ENV{USER} eq "root"))  # Running reports as root?
	{ $userid = "dummy"; }
else
	{ $userid = checkID(); }
$starttime = localtime(time);

# Get offset.  Negative mean offset in days; positive means month number (as year * 16 + month) or year alone.
unless ($dayoff = url_param("dayoff")) { $dayoff = param("dayoff"); }

$nstages = 64;		# max num of Markov chain stages
$nqtrials = ($dayoff<=0) ? 20 : ($dayoff&0xf) ? 100 : 1000;  # Number of trials to qualify for HoF: daily, monthly and yearly
$s = ($dayoff<=0) ? "Daily" : ($dayoff&0xf) ? "Monthly" : "Yearly"; 

print header;
print start_html("Card Draw Test - $s Hall of Fame");
print<<EOF0;
<body bgcolor="#FFFFFF" text="#996699" link="#3333FF" alink="#0000CC" vlink="#333366">
EOF0
print "<h1 align=\"center\"><img src=\"$Img2URL/logo.png\" width=\"275\" height=\"49\"><br>";
print<<EOF0;
<font color="#000080" size="4" face="Times New Roman">
<p>Card Draw Test - $s Hall of Fame<p>
EOF0
#print "<p><i>[Sorry, the Hall of Fame is temporarily unavailable.]</i><br>\n"; goto exit1; 

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$hhmm = sprintf("%02d:%02d", $hour, $min);
++$mon; $year += 1900; $yearT = $year;

if (!$dayoff) {					# display today
	print "as of $hhmm Pacific Time on $mon/$mday/$year";
}
elsif ($dayoff<0) {				# another day (neg offset)
	(undef,undef,undef,$mday,$mon,$year,undef,undef,undef) = localtime(time + 86400*$dayoff);
	++$mon; $year += 1900; $hhmm = "";
	print "for full day $mon/$mday/$year";
}
elsif ($mon = $dayoff&0xf) {			# a month num
	$year = $dayoff>>4; $mday = $hhmm = "";
	print "for full month $mon/$year";
}
else {						# a year num
	$year = $dayoff>>4; $mon = $mday = $hhmm = "";
	print "for full year $year";
}
print "</font></h1>\n";

# Show the form in case the user wants to pick another time period once they've seen this page.
if ($dayoff <= 0) {
	print start_form("POST", "$prog.pl");
	print "<font size=\"-1\"><center>or choose: \n"; 
	print "<select size=\"1\" name=\"dayoff\" onChange=\"submit()\">\n";

#	$ndaysp = debug() ? 2000 : 365;		# num days into the past
	$ndaysp = debug() ? (($yearT-2001)*365 + 2 + $yday) : 30;	# back to 010101 or 30 days

	$ml = 0; $yl = 0;					# last month, year
	for ($i = 0; $i >= -$ndaysp; $i--) {
		(undef,undef,undef,$d,$m,$y,undef,undef,undef) = localtime(time + 86400*$i);
		$m++; $y += 1900;
		$ym = $y<<4;				# year<<4 + month(0)
		if (debug() && $y!=$yl) {		# if year changed, add year to list
			$s = ($dayoff==$ym) ? " selected" : ""; 
			print "<option value=\"$ym\"$s>$y</option>\n";
		}
		$ym += $m;					# year<<4 + month
		if (debug() && $m!=$ml) {		# if month changed, add year+month to list
			$s = ($dayoff==$ym) ? " selected" : ""; 
			print "<option value=\"$ym\"$s>$m/$y</option>\n";
		}
		$s = ($dayoff<=0 && $i==$dayoff) ? " selected" : ""; 
		print "<option value=\"$i\"$s>$m/$d/$y</option>\n";
		$ml = $m; $yl = $y;			# month, year last
	}
	print "</select></center></font><br>\n";
	print end_form;
}

setpriority(0, $$, 20); 	# be nice - low priority

						# accumulate scores

$nlines = $ntrials = $nhits = $nusers = $nerrs = $nmessbits = 0;
#(@frch, @frht, $frmbM, @frmbA, @frmfM, @frmfA, @tarmessbitcnt, @resmessbitcnt);
foreach $i (0..20) { 					# init all freq counters
	$frch[$i] = $frht[$i] = 0;			# card hits, hits/trial
}
foreach $i (0..$nstages) { 				# init all freq counters
	$frmbM[$i] = $frmbA[$i] = 0;			# freq markov chain bits main, aux
	$frmfM[$i] = $frmfA[$i] = 0;			# freq markov chain flips main, aux
}
foreach $i (0..4) {			# trialnum%5
foreach $j (0..4) {			# cardnum
	$tarmessbitcnt[$i][$j] = $resmessbitcnt[$i][$j] = 0;	# target, result message bit counts
} }

if ($mon) { $m0 = $m1 = $mon; }
else { $m0 = 1; $m1 = 12; }
if ($mday) { $d0 = $d1 = $mday; }
else { $d0 = 1; $d1 = 31; }
$y = $year-2000;

foreach $m ($m0..$m1) {
foreach $d ($d0..$d1) {

$ymd = sprintf("%02d%02d%02d", $y, $m, $d);
$y2 = sprintf("%02d", $y);
$file = "$OLEDataDir/cardD$y2/cardD$ymd.dat";
#print "Data file name: $file<BR>";

if (debug() && $dayoff>0 && $dayoff&0xf==0) { 	# if a full year
	$| = 1; print "<i>Processing $file ...</i><br>\n"; 
}
open($fptr, $file);		# ok if not exist

								# process trials, add to db by user, tally @frch & @frht, print errs
								#   and set various other (unpassed) variables for the message
my ($nl, $nt, $nh, $nu, $ne, $pfc, $pfh) = ProcCardDData($fptr, \%db, debug() && $dayoff<=0);
#print ("$nl, $nt, $nh, $nu, $ne\n");	# debug
$nlines += $nl; $ntrials += $nt; $nhits += $nh; $nusers += $nu; $nerrs += $ne;
foreach $i (0..5) { $frch[$i] += $$pfc[$i];
 $frht[$i] += $$pfh[$i]; }

close($fptr);
} # foreach file/day
} # foreach month

foreach $user (keys(%db)) { 
	($nh, $nc) = @{$db{$user}};				# num hits, cards
	if ($nc/5 >= $nqtrials && !isBanned($user) && $user ne "") {
		$odds = getbinomodds2($nh, $nc, 0.5);	# per-card p = 1/2
		if ($nh < $nc*0.5) { $odds = -$odds; }	# neg for sort
		$hof{$user} = [$odds, $nh, $nc, 5*$nh/$nc];
	}
}

@k = sort { $hof{$b}[0] <=> $hof{$a}[0]			# sort keys by highest odds
	|| $hof{$b}[2] <=> $hof{$a}[2]			# then by most cards
	} keys %hof;	

#$n = 0; foreach $u (@k) { ++$n; print "$n: $u @{$hof{$u}}<br>\n"; }	# debug


						# Display the data in hof

print "<p><center>Total ", commify(int($ntrials/5)), " trials and ", 
	commify($ntrials), " cards by ", commify($nusers), " users";
if ($ntrials>0) {
	$hr = 5*$nhits/$ntrials;
	$hr_ = sprintf("%.3f", $hr);
	$odds = getbinomodds2($nhits, $ntrials, 0.5);
	$odds_ = commify(sprintf("%.1f", abs($odds))) . " to 1";
	if ($hr < 2.5) { $odds_ .= "-"; }
	print "<br>", commify($nhits), " hits, $hr_ hits/trial, overall odds of $odds_";
}
print "<p></center>";

# Start table and print heading row.
print<<EOF1;
  <center>
  <table border="1" width="80%">
    <tr bgcolor="#8080f0">
      <th><font color="#000000">Rank</font></th>
      <th><font color="#000000">User ID</font></th>
      <th><font color="#000000">Odds</font></th>
      <th><font color="#000000">Hits</font></th>
      <th><font color="#000000">Trials</font></th>
      <th><font color="#000000">Hits/trial</font></th>
    </tr>
EOF1

# Print table now.
$rank = 1;
foreach $user (@k) {
	($odds, $nh, $nc, $hr) = @{$hof{$user}};
	$nt = int($nc/5);					# completed trials

	$user_ = sprintf ("%s", $user);
	$user_ =~ s/\s\s/&nbsp /g;
	if (isAnon($user)) { $user_ = '[anonymous]'; }

	$odds_ = commify(sprintf("%.1f", abs($odds))) . " to 1";
	if ($odds<0) { $odds_ .= "-"; }
	$nh_ = sprintf ("%d", $nh);
	if ($nc%5==0) { $nt_ = sprintf ("%d", $nc/5); }
	else { $nt_ = sprintf ("%.1f", $nc/5); }
	
	$hr_ = sprintf ("%.2f", $hr); 
	$color = ($userid eq $user)? "\#FF0000" : "\#000080";

	if ($nt >= $nqtrials) { 
		if ($rank<=10 || $rank>(@k-10)) { $bg = "#ffe0a0"; }
		else { $bg = "#f0f0f0"; }
		print "<tr bgcolor=\"$bg\">\n";
		print "<th><font color=\"$color\">$rank<\/th>\n";
		if (($user eq $userid || debug()) && $dayoff<=0) {
			$s = "user=$user"; $s =~ s/\+/%2b/g; $s =~ s/ /\+/g;
			$s .= "&date=$ymd&test=" . "cardD";
			print "<th><a href=\"extract.pl?$s\"><font color=\"$color\">$user_</a><\/th>\n"; 
		}
		else { print "<th><font color=\"$color\">$user_<\/th>\n"; }

		print "<th><font color=\"$color\">$odds_<\/th>\n";
		print "<th><font color=\"$color\">$nh_<\/th>\n";
		print "<th><font color=\"$color\">$nt_<\/th>\n";
		print "<th><font color=\"$color\">$hr_<\/th><\/font>\n";
		print "<\/tr>\n";
	}
	++$rank;
}
 
# End the table.
print "<\/table><\/center><p>";

print "<blockquote>\n";
printhof1(0, $nqtrials);
print "Each card has probability of 1/2 of being a picture, thus about 2.5 hits/trial are expected by chance. ";
printhof2(); 
print "</blockquote>\n";

if (1||debug()) { 			# draw frequency bar charts
	$yr = sprintf("%02d", $year-2000);
	print "<p><center>";
	$freqs_ = "str=+card+hits++$mon/$mday/$yr";
	foreach $i (1..5) { $freqs_ .= "&f$i=$frch[$i]"; }	# card hit freqs
#	print "$freqs_<br>\n";		# debug
	print "<img src=\"$ProgURL/chartim.pl?$freqs_\">\n";

	print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";

	$freqs_ = "str=+hits/trial++++$mon/$mday/$yr";
	$freqs_ .= "&n0=0&n1=5";
	foreach $i (0..5) { $freqs_ .= "&f$i=$frht[$i]"; }	# hits/trial freqs
#	print "$freqs_<br>\n";		# debug
	print "<img src=\"$ProgURL/chartim.pl?$freqs_\">\n";
	print "</center><p>\n";
}

if (debug() && $dayoff<=0 && $ntrials>0) { 
	$p = getchisqp(@frch[1..5]); if ($p<1e-10) { $p = 1e-10; }
	printf "<center><i>Card hits chisq 1/p = %.1f</i></center><p>\n", 1/$p;
}

if (0 && debug() && $dayoff<=0) { 		# analyze bit counts to get message target and result
	$tmess = $rmess = "";			# target, result message str
	$nrbcor = 0;				# num result bits correct
	foreach $i (0..4) { 			# (trialnum-1)%5
		$tarmess[$i] = $resmess[$i] = 0; 
		foreach $j (0..4) {		# bit/card num
			$bt = ($tarmessbitcnt[$i][$j]>=$nmessbits/50) ? 1 : 0;	# majority vote
			$tarmess[$i] |= ($bt<<$j);
			$br = ($resmessbitcnt[$i][$j]>=$nmessbits/50) ? 1 : 0;	# majority vote
			$resmess[$i] |= ($br<<$j); 
			$nrbcor += $bt==$br;							# count correct bits
			print "$tarmessbitcnt[$i][$j] $resmessbitcnt[$i][$j], ";	# debug
		}
		$bitscor = $tarmess[$i]^$resmess[$i]^0x1f;				# bits correct
		printf(" &nbsp %05b, %05b => %05b<br>\n", $tarmess[$i], $resmess[$i], $bitscor);	# debug
		$tmess .= getmesschar($tarmess[$i]); 					# corresponding char
		$rmess .= getmesschar($resmess[$i]); 
	}
	$ntmb0 = $nmessbits-$ntmb1; $nrmb0 = $nmessbits-$nrmb1;
	print "<i>Target message: \"$tmess\", Result message: \"$rmess\", ";
	print "$ntmb0/$ntmb1, $nrmb0/$nrmb1, $nrbcor/25</i><p>\n";
}

if (debug() && $dayoff<=0) { 			# draw z line charts
	print "<p><center><table>";	
	$n = ($Mn>0) ? $Mn-1 : 9;		# use size of the last trial

#	print "<td><font size=1>$mon/$mday/$yr $hhmm $Mn,$Mi,$Mk<br><br>$ntrials<br>\n";
#	foreach $i (0..$n) { print "$frmbM[$i], $frmfM[$i]<br>"; }	# main bit, flip freqs
#	print "<br><br>$ntrials<br>\n";
#	foreach $i (0..$n) { print "$frmbA[$i], $frmfA[$i]<br>"; }	# aux bit, flip freqs
#	print "</font></td>
	print "<br><td>\n";

	$freqs_ = "str=+main+bits+z++$mon/$mday/$yr+$hhmm++$Mn,$Mi,$Mk";
	$freqs_ .= "&zr=3&n0=0&n1=$n";					# z range, first, last
	foreach $i (0..$n) {
		$v = sprintf("%.1f", getz($frmbM[$i], $ntrials, 0.5)); # main bit freqs
		$freqs_ .= "&f$i=$v"; 
	}
#	if (debug()) { print "$freqs_<br>\n"; }
	print "<img src=\"$ProgURL/chartim.pl?$freqs_\"><br>\n";	# display chart

	$freqs_ = "str=+aux+bits+z++$mon/$mday/$yr+$hhmm++$Mn,$Mi,$Mk";
	$freqs_ .= "&zr=3&n0=0&n1=$n";					# z range, first, last
	foreach $i (0..$n) {
		$v = sprintf("%.1f", getz($frmbA[$i], $ntrials, 0.5)); # aux bit freqs
#		$v = sprintf("%.1f", ($i/$n)*6-3);	# debug
		$freqs_ .= "&f$i=$v"; 
	}
#	if (debug()) { print "$freqs_<br>\n"; }
	print "<img src=\"$ProgURL/chartim.pl?$freqs_\"><br>\n";	# display chart

	print "</td><td>\n";

	$freqs_ = "str=+main+flips+z++$mon/$mday/$yr+$hhmm++$Mn,$Mi,$Mk";
	$freqs_ .= "&zr=3&n0=1&n1=$n";					# z range, first, last
	foreach $i (1..$n) {
		$v = sprintf("%.1f", getz($frmfM[$i], $ntrials, 1/2**$Mk));	# chain flip freqs
		$freqs_ .= "&f$i=$v"; 
	}
#	if (debug()) { print "$freqs_<br>\n"; }
	print "<img src=\"$ProgURL/chartim.pl?$freqs_\"><br>\n";	# display chart

	$freqs_ = "str=+aux+flips+z++$mon/$mday/$yr+$hhmm++$Mn,$Mi,$Mk";
	$freqs_ .= "&zr=3&n0=1&n1=$n";					# z range, first, last
	foreach $i (1..$n) {
		$v = sprintf("%.1f", getz($frmfA[$i], $ntrials, 1/2**$Mk));	# aux flip freqs
		$freqs_ .= "&f$i=$v"; 
	}
#	if (debug()) { print "$freqs_<br>\n"; }
	print "<img src=\"$ProgURL/chartim.pl?$freqs_\"><br>\n";	# display chart

	print "</td></table></center><p>\n";
}

print "<ul><blockquote>\n";
print "<li>Restart the <a href=\"$HtmlURL/cardD.htm\">         Card Draw Test                     </a></li>\n";
#print "<li>See     the <a href=\"$HtmlURL/HoFs/cardDhofM.htm\">Card Draw Test Monthly Hall of Fame</a></li>\n";
#print "<li>See     the <a href=\"$HtmlURL/HoFs/cardDhofY.htm\">Card Draw Test Yearly Hall of Fame </a></li>\n";
print "<li>Go to the <a href=\"$ProgURL/cardDusum.pl\">Card Draw Test User Results Summary</a></li>\n";
printchoices();
print "</ul></blockquote>\n";

exit1:
printsysmsg();		# system message
print end_html;

writeMiscFile("cardDhof",$starttime);
sleep(3);			# prevent repeated use
exit(0); 

###################

sub getmesschar {			# get message character from the bits
	my $bits = $_[0];	

	my $ch = ($bits>=1 && $bits<=26) ? chr($bits-1+ord('a')) : '_';
	return $ch;
}


