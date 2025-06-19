#!/usr/bin/perl -w
						# Card Draw Test User Summary
use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
require "OLEinit.pl";
require "OLEutils.pl";
require "OLEmath.pl";
require "OLEerr.pl";
require "cardDdata.pl";

$prog = "cardDusum";			# this program

$userid = checkID();
if (($u = param('user')) || (debug()&&($u = url_param('user')))) { $userid = $u; }

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$hhmm = sprintf("%02d:%02d", $hour, $min);
++$mon; $year += 1900; $yearT = $year;
$ymdT = sprintf("%02d%02d%02d", $year-2000, $mon, $mday);	# ymd today
$ym_T = sprintf("%02d%02d%02d", $year-2000, $mon, 0);		# ym_ today
$y__T = sprintf("%02d%02d%02d", $year-2000, 0, 0);		# y__ today

							# offset (neg) num days or (pos) year<<4 + month
if (!($dayoff = param("dayoff")) && debug()) { $dayoff = url_param('dayoff'); }
if ($dayoff==0) { $dayoff = ($year<<4)+$mon; }	# can't see today, default to this month

#$nqtrials = ($dayoff<=0) ? 20 : (($dayoff&0xf) ? 200 : 1000);	# num trials to qualify
$nqtrials = 0;					# show all

print header;
print start_html("Card Draw Test - Results Summary by User");
print<<EOF0;
<body bgcolor="#FFFFFF" text="#996699" link="#3333FF" alink="#0000CC" vlink="#333366">
<h1 align="center"><img src="$Img2URL/logo.png" width="275" height="49"><br>
<font color="#000080" size="4" face="Times New Roman">
<p>Card Draw Test - Results Summary <br>for User \"$userid\"<br>
EOF0

if ($dayoff==0) {					# display today
	print "as of $hhmm Pacific Time on $mon/$mday/$year";
	$mode = 0;
}
elsif ($dayoff<0) {				# another day (neg offset)
	(undef,undef,undef,$mday,$mon,$year,undef,undef,undef) = localtime(time + 86400*$dayoff);
	++$mon; $year += 1900; $hhmm = "";
	print "for full day $mon/$mday/$year";
	$mode = 0;
}
elsif ($mon = $dayoff&0xf) {			# a month by days
	$year = $dayoff>>4; $mday = $hhmm = "";
	print "for full month $mon/$year";
	$mode = 1;
}
elsif ($dayoff<100000) {			# a year (y<<4) by months
	$year = $dayoff>>4; $mon = $mday = $hhmm = "";
	print "for full year $year";
	$mode = 2;
}
elsif ($dayoff==100000) {			# years 2000-now by year
	$year = $mon = $mday = $hhmm = "";
	print "for years 2001-$yearT";
	$mode = 3;
}
else { GenErr("$prog: Unknown date = $dayoff"); exit(); }
print "</font></h1>\n";

if (1||$dayoff <= 0) {
	print start_form("POST", "$prog.pl");
	print "<font size=\"-1\"><center>or choose: \n";
	print "<select size=\"1\" name=\"dayoff\" onChange=\"submit()\"><br>\n";

#	$ndaysp = debug() ? 2000 : 365;		# num days into the past
	$ndaysp = ($yearT-2001)*365 + 2 + $yday;	# back to 010101

	$s = ($dayoff>=100000) ? " selected" : "";	# all years
	if (1||debug()) { print "<option value=\"100000\"$s>2001-$yearT</option>\n"; }

	$ml = 0; $yl = 0;					# last month, last year
	for ($i = -1; $i >= -$ndaysp; $i--) {
		my (undef,undef,undef,$d,$m,$y,undef,undef,undef) = localtime(time + 86400*$i);
		$m++; $y += 1900; 
		$ym = $y<<4;				# year<<4 + month(0)
		if ($y!=$yl) {				# if year changed, add year to list
			$s = ($dayoff==$ym) ? " selected" : ""; 
			print "<option value=\"$ym\"$s>$y</option>\n";
		}
		$ym += $m;					# year<<4 + month
		if ($m!=$ml) {				# if month changed, add year+month to list
			$s = ($dayoff==$ym) ? " selected" : ""; 
			print "<option value=\"$ym\"$s>$m/$y</option>\n";
		}
		$s = ($dayoff<=0 && $i==$dayoff) ? " selected" : ""; 
		print "<option value=\"$i\"$s>$m/$d/$y</option>\n";
		$ml = $m; $yl = $y;			# month, year last
	}
	print "</select></font><br>\n";
	if (debug()) {
		print "UserID <input type=\"text\" value=\"$userid\" name=\"user\" size=25 maxlength=40>\n";
		print "  <input type=\"submit\" value=\"Go\" name=\"submit\"><br>\n";
	}
	print "</center>\n";
	print end_form;
}

						# accumulate scores

$nlines = $ntrials = $nhits = $ndays = 0; 
foreach $i (0..20) { $frz[$i] = 0; }		# z freqs
@dbd = @dbm = @dby = ();
$dayi = $moni = $yri = 1;				# day, month, year index

if ($year) { $y0 = $y1 = $year-2000; }
else { $y0 = 1; $y1 = $yearT-2000; }
if ($mon) { $m0 = $m1 = $mon; }
else { $m0 = 1; $m1 = 12; }
if ($mday) { $d0 = $d1 = $mday; }
else { $d0 = 1; $d1 = 31; }

foreach $y ($y0..$y1) {		# each year
	$y2 = sprintf("%02d", $y);
	$nhy = $nty = 0;
foreach $m ($m0..$m1) {		# each month
	$nhm = $ntm = 0;					# hits, trials this month
foreach $d ($d0..$d1) {		# each day

if (($d==31 && ($m==2 || $m==4 || $m==6 || $m==9 || $m==11)) ||	# 30 days hath Sep ...
	($d==30 && $m==2) || ($d==29 && $m==2 && ($y%4!=0 || $y%100==0))) { next; }

$ymd = sprintf("%02d%02d%02d", $y, $m, $d);
$ym_ = sprintf("%02d%02d%02d", $y, $m, 0);
$y__ = sprintf("%02d%02d%02d", $y, 0, 0);

$dirD = "$OLEDataDir/cardD$y2"; $dirS = "$OLESummDir/cardD$y2";
$fileS = "cardD$ymd"."S.dat";				# summary file

if (!-e "$dirS/$fileS" && $ymd<$ymdT) {		# if not there and before today
	if (debug()) { print "<i>Creating summary file for $ymd</i><br>\n"; }
	MakeCardDDataSummFile("cardD$ymd.dat", $dirD, $dirS);	# make summary file
}

#if (debug()) { $| = 1; print "<i>Processing $fileS ...</i><br>\n"; }
unless (open(IN, "$dirS/$fileS")) { 
	if (debug() && $ymd<$ymdT) { print "<i>Unable to open summary file for $ymd</i><br>\n"; }
	$dbd[$dayi++] = [$ymd, 0, 0, 0, 0, 0];	# database by day
	next; 		# still missing, punt on this one
}
@data = <IN>;		 
close IN;

$nt = $nh = $z = 0; 					# stats for this day

foreach $line (@data) {
	$nlines++;
	$line =~ s/\\//g;
	$line =~ s/\|//g;
	@l = split(m/,/, $line);
#print OutSumm "$user,$hitn,$trn,$z\n";		# output by summ program for each user on this day
#mahala, 200, 1000, 1.00				# example line

	$user = $l[0]; 
	if ($user eq $userid) { 			# found the user
		$nh = $l[1]; $nt = $l[2]; $z = $l[3];	# num trials, hits, z for this user, this line

		$err = 0;
		if ($#l!=3) { $err++; }			# test for errors here
		if ($err) { 
			if (debug()) { print "<i>bogus line: $line</i><br>\n"; }
			next; 
		}

		$ndays++;					# days this user was active
		last;						# assume only one line for this user
	}
} # foreach line

	if ($nt>0) {
		$z = getz($nh, $nt, 0.5);
		$frz[2*$z+10+.5]++; 				# daily z buckets
		$hr = 5*$nh/$nt;					# hit rate
		$odds = getbinomodds2($nh, $nt, 0.5);
		if ($z<0) { $odds = -$odds; }			# neg for sort
	} else { $z = $hr = 0; $odds = 1.0; }

	$dbd[$dayi++] = [$ymd, $odds, $nh, $nt, $hr, $z];	# database by day
	$nhm += $nh; $ntm += $nt;				# month hits, trials for this user
} # foreach file/day

	if ($ntm>0) {
		$z = getz($nhm, $ntm, 0.5);
		$hr = 5*$nhm/$ntm;				# hit rate
		$odds = getbinomodds2($nhm, $ntm, 0.5);
		if ($z<0) { $odds = -$odds; }			# neg for sort
	} else { $z = $hr = 0; $odds = 1.0; }

	$dbm[$moni++] = [$ym_, $odds, $nhm, $ntm, $hr, $z];	# database by month
	$nhy += $nhm; $nty += $ntm;				# year hits, trials for this user
} # foreach month

	if ($nty>0) {
		$z = getz($nhy, $nty, 0.5);
		$hr = 5*$nhy/$nty;				# hit rate
		$odds = getbinomodds2($nhy, $nty, 0.5);
		if ($z<0) { $odds = -$odds; }			# neg for sort
	} else { $z = $hr = 0; $odds = 1.0; }

	$dby[$yri++] = [$y__, $odds, $nhy, $nty, $hr, $z];	# database by year
	$nhits += $nhy; $ntrials += $nty;			# total hits, trials for this user
} # foreach year

#if (debug()) { $i=0; foreach (@dbd) { print "$i: @$_<br>\n"; $i++; } }	# debug

@db = ($mode<=1)?@dbd : ($mode==2)?@dbm : ($mode==3)?@dby : 0;		# sort here too if desired

						# Display the data

$nitems = ($mode==0)?1 : ($mode==1)?min($dayi-1,31) : ($mode==2)?12 : ($mode==3)?($yearT-2000) : 0;	# num items to display

print "<p><center>Total ", commify(int($ntrials/5)), " trials and ", 
	commify($ntrials), " cards over ", commify($ndays), " days";
if ($ntrials>0) {
	$hr = 5*$nhits/$ntrials;
	$hr_ = sprintf("%.3f", $hr);
	$odds = getbinomodds2($nhits, $ntrials, 0.5);
	$odds_ = commify(sprintf("%.1f", abs($odds))) . " to 1";
	if ($hr < 2.5) { $odds_ .= "-"; }
	print "<br>", commify($nhits), " hits, $hr_ hits/trial, overall odds of $odds_";
}
print "<p></center>";

print<<EOF1;
  <center>
  <table border="1" width="80%">
    <tr bgcolor="#8080f0">
      <th><font color="#000000">#</font></th>
      <th><font color="#000000">Date</font></th>
      <th><font color="#000000">Odds</font></th>
      <th><font color="#000000">Hits</font></th>
      <th><font color="#000000">Trials</font></th>
      <th><font color="#000000">Hits/trial</font></th>
    </tr>
EOF1

foreach $it (1..$nitems) {
	my ($date, $odds, $nh, $nt, $hr, $z) = @{$db[$it]};

	$date =~ /(\d\d)(\d\d)(\d\d)/; $y = $1+2000; $m = $2; $d = int($3);
	$date_ = sprintf("%s %s %4d", ($mode<=1)?"$d":"", ($mode<=2)?$MonthNames[$m]:"", $y);
	$odds_ = commify(sprintf("%.1f", abs($odds))) . " to 1";
	if ($odds<0) { $odds_ .= "-"; }
	$nh_ = sprintf ("%d", $nh); 
	if ($nt%5==0) { $nt_ = sprintf ("%d", $nt/5); }
	else { $nt_ = sprintf ("%.1f", $nt/5); }
	$hr_ = sprintf ("%.2f", $hr); 
	$z_  = sprintf ("%.1f", $z);
	$color = ($date<$ymdT) ? "#000080" : "#606080";		# text, greyed if not past

	if ($nt >= $nqtrials) { 
		$bg = "#f0f0f0"; 
		print "<tr bgcolor=\"$bg\">\n";
		print "<th><font color=\"$color\">$it<\/th>\n";
		if ($mode<=1) {					# link to trials if day or month
			$s = "user=$userid"; $s =~ s/\+/%2b/g; $s =~ s/ /\+/g;	# fix + and spaces
			$s .= "&date=$date&test=cardD";
			if ($date<$ymdT) { print "<th><a href=\"extract.pl?$s\"><font color=\"$color\">$date_</a><\/th>\n"; }
			else { print "<th><font color=\"$color\">$date_<\/th>\n"; }
		}
		elsif ($mode==2) {				# link to month if year
			$s = "user=$userid&dayoff=" . (($y<<4)+$m);
			if ($date<=$ym_T) { print "<th><a href=\"$prog.pl?$s\"><font color=\"$color\">$date_</a><\/th>\n"; } 
			else { print "<th><font color=\"$color\">$date_<\/th>\n"; }
		}
		elsif ($mode==3) { 				# link to year if all years
			$s = "user=$userid&dayoff=" . ($y<<4);
			if ($date<=$y__T) { print "<th><a href=\"$prog.pl?$s\"><font color=\"$color\">$date_</a><\/th>\n"; }
			else { print "<th><font color=\"$color\">$date_<\/th>\n"; }
			}

		if ($nt>0) {
			print "<th><font color=\"$color\">$odds_<\/th>\n";
			print "<th><font color=\"$color\">$nh_<\/th>\n";
			print "<th><font color=\"$color\">$nt_<\/th>\n";
			print "<th><font color=\"$color\">$hr_";
			if (debug()) { print " ($z_)"; }
			print "<\/th>\n"; 
		} else {
			print "<th><font color=\"$color\">--<\/th>\n";
			print "<th><font color=\"$color\">--<\/th>\n";
			print "<th><font color=\"$color\">--<\/th>\n";
			print "<th><font color=\"$color\">--<\/th>\n";
		}
		print "<\/tr>\n";
	}
}
 
print "<\/table><\/center><p>";

print "<blockquote>\n";
print "Results are updated each day at midnight Pacific Time. Note that today's data are not included until tomorrow.\n";
#printhof2();
print "</blockquote>\n";

if (debug() && $mode>0) { 		# z scores by day
	$yr = ($year) ? sprintf("%02d", $year-2000) : "";
	print "<center><p>";
	$freqs_ = "str=+z+scores";		# make string of params
	$freqs_ .= ($mode==1) ? "+by+day" : ($mode==2) ? "+by+month" : ($mode==3) ? "+by+year" : "??";
	$freqs_ .= "+$mday/$mon/$yr";
	$freqs_ .= "&n0=1&n1=$nitems";
	foreach $i (1..$nitems) { $freqs_ .= sprintf("&f$i=%.1f", $db[$i][5]); }
#	print "$freqs_<br>\n";						# debug
	print "<img src=\"$ProgURL/chartim.pl?$freqs_\">\n";		# display freqs

	if ($mode>0 && $ntrials>0) { 					# get chisquare of z scores
#		$p = getchisqp(@db[1..$nitems][5]); if ($p<1e-10) { $p = 1e-10; }
#		print "@db[1..$nitems][5]";	???
#		printf "<br><i>z score chisq 1/p = %.1f</i>\n", 1/$p;
	}
	print "</center><p>\n";
}

if (debug()) { 				# z scores histogram
	$yr = ($year) ? sprintf("%02d", $year-2000) : "";
	print "<center><p>";
	$freqs_ = "str=+z+score+freqs+by+day+$mday/$mon/$yr";	# make string of params
	$freqs_ .= "&n0=0&n1=20&noff=-5&ninc=.5";
	foreach $i (0..20) { $freqs_ .= "&f$i=$frz[$i]"; }
#	print "$freqs_<br>\n";						# debug
	print "<img src=\"$ProgURL/chartim.pl?$freqs_\">\n";		# display freqs
	print "</center><p>\n";
}

print "<ul><blockquote>\n";
print "<li>Go to the <a href=\"$HtmlURL/cardD.htm\"         >Card Draw Test                     </a> or today's <a href=\"cardDhof.pl\">Card Draw Test Hall of Fame</a></li>\n";
#print "<li>See   the <a href=\"$HtmlURL/HoFs/cardDhofM.htm\">Card Draw Test Monthly Hall of Fame</a></li>\n";
#print "<li>See   the <a href=\"$HtmlURL/HoFs/cardDhofY.htm\">Card Draw Test Yearly Hall of Fame </a></li>\n";
printchoices();
print "</ul></blockquote>\n";

printsysmsg();		# system message
print end_html;

writeMiscFile("cardDusum ($userid)", ($dayoff<0) ? "$ymd" : sprintf("%d/%d", $dayoff&0xf, $dayoff>>4));
exit(0); 


