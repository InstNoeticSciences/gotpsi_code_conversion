#!/usr/bin/perl -w

use CGI qw(:standard);
use CGI::Carp qw/fatalsToBrowser/;
require "OLEutils.pl";
require "OLEerr.pl";
require "OLEmath.pl";
require "OLErand.pl";

$userid = checkID();

my $refer = referer();				# browsers sometimes don't send
#unless ($refer =~ "cardD" || $refer =~ "cardDlog") {
#	SeqErr("cardD: $refer");		# sequence error
#	exit();
#}

unless ($trperrun = param('trperrun')) { $trperrun = 10; }						# number of trials in a run
if ($tarims = param('tarims')) { $ntargets = int($tarims/100); $target0 = $tarims%100; }	# num tars, first tar index
else { $ntargets = 40; $target0 = 1; }

						# get params
$trialnum = cookie(-name=>'cardDtrialnum');	# cur trial num
$runhits = param('runhits');				# num hits this run
if (!defined($trialnum) || $trialnum eq "" || $trialnum == 0 || $trialnum >= $trperrun || !defined($runhits)) { 
	$trialnum = 1; $runhits = 0;
}
else { ++$trialnum; }

$nimages = $ntargets; $im0 = $target0;
#$imdir = "../images2/";					# card images to use
$hitimage = "c" . (getrandint($nimages)+$im0) . ".jpg"; 	# target image

$rcode1 = getrandint(100);				# random code
do { $rcode2 = getrandint(100);			# another one, different
} until ($rcode2 != $rcode1);

						# update the cookies
$cookie1 = cookie(  -name=>'rcode', 
     		        -value=>$rcode1, 
                    -path=>"/",
                    -expires=>'+1d');

$cookie2 = cookie( -name=>'cardDtrialnum',
                   -value=>$trialnum,
                   -path=>"/",
                   -expires=>'+1d');

$cookie3 = cookie( -name=>'cardDbits',
                   -value=>0,
                   -path=>"/",
                   -expires=>'+1d');

						# display the page
print header(-cookie=>[$cookie1,$cookie2,$cookie3]);
print start_html("Card Draw Test");

print<<EOF0;
<body bgcolor="#FFFFFF" text="#000080" link="#3333FF" alink="#0000CC" vlink="#333366">
<p><br><center><font color="#000080"><h1>Card Draw Test</h1></font></center>
EOF0

print "<center><b>User</b> $userid &nbsp&nbsp <b>Trial</b> $trialnum / $trperrun</center><br>\n";
print "<center>Turn over each card and make the target <a href=\"$Img2URL/$hitimage\">
	<img src=\"$Img2URL/$hitimage\" width=40 height=50></a> appear as many times as possible<p>\n";
#$r1 = ($refer =~ "cardD"); $r2 = ($refer =~ "cardDlog");	# debug
#print "$refer, $r1, $r2";			# debug

print start_form("POST","cardDlog.pl");
print "<input type=\"hidden\" name=\"trperrun\" value=$trperrun>\n";
print "<input type=\"hidden\" name=\"tarims\" value=$tarims>\n";
print "<input type=\"hidden\" name=\"rcode\" value=$rcode2>\n";
print "<input type=\"hidden\" name=\"runhits\" value=$runhits>\n";
print "<input type=\"hidden\" name=\"hitimage\" value=$hitimage>\n";

foreach $j (0..4) {
	print "<input type=\"image\" name=\"card$j\" ";
	print "src=\"$Img2URL/cback5.jpg\" width=130 height=157>\n";
}

print "</center>\n";

# print "<p>Referring page = ",referer();

print end_form;
print end_html;
