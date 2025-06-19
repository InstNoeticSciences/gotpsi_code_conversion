#!/usr/bin/perl -w
						# Card Draw Test data processor

sub ProcCardDData {	# process cardD data lines, add to data hash by user
				# returns $nlines, $ntrials, $nhits, $nusers, $nerrs, @frch, @frht	
				#	total trials, hits, users, errors, tar freqs, hit/trial freqs
				#     and sets several other (unpassed) variables for the message

	my $fptr = $_[0]; my $dbref = $_[1]; my $prterrs = $_[2];  # input data lines, ref to output %db, print errors
	my ($nlines, $ntrials, $nhits, $nusers, $nerrs, @frch, @frht) = ( 0, 0, 0, 0, 0, (), () );
	my ($user, $ccb, $cch, $MbitsM, $MbitsA, $tarb, $resb, $cardnum, $trialnum, $hit, $runhits, $nh, $nc, $err);

foreach $line (<$fptr>) {
#	if ($line =~ /_test99/) { next; }		# avoid showing testing
	$nlines++;
	$line =~ s/\\//g;
	$line =~ s/\|//g;
	$line =~ s/, /,/g; 
	my @l = split(m/,/, $line);
								# prior to 060622, Mbits main & aux in same 32-bit word
								# beginning 060622, Mbits main & aux in separate words, line 1 longer
#print LOGFILE "$userid, ~$tarb, $ccb, $cch, $Mn, $Mi, $Mk, ($MbitsM<<$Mn)|$MbitsA,";	# prior to 060622
#print LOGFILE "$userid, ~$tarb, $ccb, $cch, $Mn, $Mi, $Mk, $MbitsM, $MbitsA,";		# beginning 060622
#print LOGFILE " $card, $hit, $runhits, $trialnum, $timeval, $imcard,\n";
#vogelaj, 0, 1, 1, 10, 9, 2, 990979, 0, 1, 1, 1, Mon Feb 16 00:14:20 2004, c3.jpg,
#[note: Target bit ($tarb) added 060218 about 1240; Prior to that target was always 1.]

	$user = $l[0]; if (length($user)>30) { next; }

	$err = $i = 0;
	$ccb = $l[2]; $cch = $l[3];				# count of cardbits, cardhits
	($Mn, $Mi, $Mk) = @l[4..6];				# chain params
	if ($#l==14) {				# prior to 6/22/06, Mbits main & aux in same word
		$MbitsM = $l[7] & (1<<$Mn)-1; 		# both chains in one word
		$MbitsA = ($l[7]>>$Mn) & (1<<$Mn)-1;
	}
	elsif ($#l==15) {				# beg 6/22/06, Mbits main & aux in separate words
		$MbitsM = $l[7]; $MbitsA = $l[8]; $i = 1;
	}
	else { $err = 1; }

	$tarb = $l[1]^1; $resb = ($MbitsM>>$Mi)&1;	# target (stored compl), result bit
	$cardnum = $l[8+$i]; $trialnum = $l[11+$i];
	$hit = int($l[9+$i]); $runhits = $l[10+$i];

	if ($cardnum<0 || $cardnum>4 ||			# cardnum out of range
		$trialnum>25 || $trialnum<1 ||		# trialnum out of range
		$ccb>5 || $cch>5 || 	 			# counts out of range
		$tarb>1 || ($hit && $tarb!=$resb) ||	# hit but no bit match
		($hit && $runhits<1)) { $err =1; }		# hit but no runhits

	if ($err) {
		if ($prterrs) { printf "Bogus cardD trial: @l, $tarb, $resb, %x<br>\n", $Mbits; }
		$nerrs++; next; 
	}

#	if (debug()) {
#		print "<i>substituting debug data...</i><br>\n";
#		if (($trialnum&7)<2) { $resb = $tarb; $hit = 1; }
#		print "$trialnum,$cardnum: @l, $tarb, $resb<br>\n";
#	}
	if ($hit) { $frch[$cardnum+1]++; } 		# card hit freqs
	if ($ccb==5) { $frht[$cch]++; }		# hits/trial freqs
	$tarmessbitcnt[($trialnum-1)%5][$cardnum] += $tarb;	# num of 1s this pos in tar mess
	$resmessbitcnt[($trialnum-1)%5][$cardnum] += $resb;	# num of 1s this pos in res mess
	$ntmb1 += $tarb; $nrmb1 += $resb; $nmessbits++;		# total num 1s

	foreach $i (0..$Mn-1) {				# main chain stage freqs
		$frmbM[$i] += $MbitsM&1 ^ ($tarb?0:1);				# main bits (comp if tar==0)
		$frmfM[$i+1] += (($MbitsM&1)==($MbitsM>>1&1)) ? 0 : 1; 	# main flips (diff from next)
		$MbitsM >>= 1;
	}
	foreach $i (0..$Mn-1) {				# aux chain stage freqs
		$frmbA[$i] += $MbitsA&1 ^ ($tarb?0:1); 				# aux bits (comp if tar==0)
		$frmfA[$i+1] += (($MbitsA&1)==($MbitsA>>1&1)) ? 0 : 1; 	# aux flips (diff from next)
		$MbitsA >>= 1;
	}

	$ntrials++; $nhits+=$hit;			# total trials, hits

	if ($dbref->{$user}) { 				# already in hash?
		($nh, $nc) = @{$dbref->{$user}}; 	# [0] = $nh = num hits, [1] = $nc = num cards
		$dbref->{$user} = [$nh+$hit, $nc+1]; 
	}
	else { 						# new user
		$dbref->{$user} = [$hit, 1]; 
		$nusers++; 
	}

} # foreach line

	return wantarray ? ($nlines, $ntrials, $nhits, $nusers, $nerrs, \@frch, \@frht) : undef;
}


sub MakeCardDDataSummFile {		# make Card Draw Test daily summary file from daily raw data file
	my ($dfile, $indir, $outdir) = @_;		# data filename, input dir, output dir
	my ($nl, $nt, $nh, $nu, $ne, $z);		# lines, trials, hits, users, errors, z score
	my ($fptr, %db, %hof); 

	open ($fptr, "$indir/$dfile");	# process data lines, return db by user, don't print errs
	($nl, $nt, $nh, $nu, $ne, undef, undef) = ProcCardDData($fptr, \%db, 0);
	close($fptr);

	foreach $user (keys(%db)) { 
		my ($nh, $nc) = @{$db{$user}};	# hits, cards
		$z = getz($nh, $nc, 0.5);
		$hof{$user} = [$nh, $nc, $z];
	}

	@k = sort { $hof{$b}[1] <=> $hof{$a}[1] } keys %hof;	# sort by most cards
		
	$dfile =~ s/\.dat$/S.dat/;			# append S for Summary to filename
	unless (open(OUT, ">$outdir/$dfile")) {	# file with data summary by user
		if (debug()) { print "<i>Can't write $outdir/$dfile</i><br>\n"; }
	}

	foreach $user (@k) { 
		printf OUT "$user, $hof{$user}[0], $hof{$user}[1], %+.2f\n", $hof{$user}[2]; 
	}
	close(OUT);

	return wantarray ? ($nl, $nt, $nh, $nu, $ne) : undef;
}


1;
