package Aviation::Report;

use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	decode_METAR_TAF decode_PIREP
);
$VERSION = '1.01';

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

   my %abb = ();

   open(X, "metar.txt") or die "cannot open METAR/TAF dictionary: $!";

   while (<X>) {
      chomp;
      next if /^#?$/;
      my ($abbrev, $desc) = split /:/;
      $abb{$abbrev} = $desc;
   }

   close X;

   my @low = ('None', 'Cumulus  (fair wx)', ' Cumulus (towering)', 'Cumulonimbus (no anvil)', 'Stratocumulus', 'Stratocumulus', 'Stratus', 'Fractocumulus/Fractostratus', 'Cumulus and Stratocumulus', 'Cumulonimbus');

   my @middle = ('None', 'Altostratus (thin)', 'Altostratus (thick)', 'Altocumulus (thin)', 'Altocumulus (patchy)', 'Altocumulus (thickening)', 'Altocumulus (from Cumulonimbus)', 'Altocumulus (w/Ac,As,Ns)', 'Altocumulus (w/turrets)', 'Altocumulus (chaotic)');

   my @high = ('None', 'Cirrus (filaments)', 'Cirrus (dense)', 'Cirrus (often w/Cb)', 'Cirrus (thickening)', 'Cirrus/Cirrostratus (low in sky)', 'Cirrus/Cirrostratus (high in sky)', 'Cirrostratus (entire sky)', 'Cirrostratus (partial)', 'Cirrocumulus or Cirrocumulus/Cirrus/Cirrostratus');

   my %abb_pirep = ( UA => 'routine pilot report',
                     UUA => 'urgent pilot report',
                     OV => 'location',
                     TM => 'time',
                     FL => 'altitude',
                     TP => 'type of aircraft',
                     SK => 'sky cover',
                     WX => 'weather',
                     TA => 'temperature',
                     WV => 'wind',
                     TB => 'turbulence',
                     IC => 'icing',
                     RM => 'remarks',
                     CLR => 'clear',
                     LGT => 'light',
                     MDT => 'moderate',
                     HVY => 'heavy',
   );
1;

sub decode_PIREP {
   my ($s, $style) = @_;
   my $s = uc $s;
   my ($out) = $s . "\n" if $style;

   my $token;

   my @tokens = split m:/:, $s;

   while ($token = shift @tokens) {
         my ($element, $value) = ('', '');
         if (($element, $value) = split / /, $token, 2) {
            if (exists $abb_pirep{$element}) {
               $out .= $abb_pirep{$element} . ' ';
            }
            else {
               if ($element =~ /^(\d{3})$/) {
                  $out .= int($1)."00 feet ";
                  foreach (split / /, $value) {
                     if (/^(\d{3})$/) {
                        $out .= int($1)."00 feet ";
                     }
                     elsif (/^([A-Z]+)$/) {
                        if (exists $abb{$1}) {
                           $out .= $abb{$1} . ' ';
                        }
                        else {
                           $out .= $1 . ' ';
                        }
                     }
                     else {
                        $out .= $_;
                     }
                  }
               }
               else {
                  $out .= $element;
               }
               $out .= "\n";
               next;
            }
            if ($element eq 'IC' or $element eq 'TB') {
               if (exists $abb_pirep{$value}) {
                  $out .= $abb_pirep{$value};
               }
               else {
                  $out .= $value;
               }
            }
            elsif ($element eq 'OV' and $value =~ /^(.*?) (\d{3})(\d{3})$/) {
               $out .= int($2) ." nautical miles on the $3 degree radial from $1";
            }
            elsif ($element eq 'SK') {
               foreach (split / /, $value) {
                  if (/^(\d{3})$/) {
                     $out .= int($1)."00 feet msl ";
                  }
                  elsif (/^([A-Z]+)$/) {
                    if (exists $abb{$1}) {
                       $out .= $abb{$1};
                    }
                    else {
                       $out .= $1;
                    }
                  }
                  else {
                     $out .= $_;
                  }
               }
            }
            elsif ($value =~ /^(\d{3})(\d{3})$/) {
               $out .= "from $1 degrees magnetic at @{[int $2]} knots";
            }
            elsif ($value =~ /^(\d{2})(\d{2})$/) {
               $out .= "$1:$2 zulu";
            }
            elsif ($value =~ /^(\d{3})$/) {
               $out .= int($1)."00 feet msl ";
            }
            else {
               $out .= $value;
            }
            $out .= " degrees Celsius" if $element eq 'TA';
            $out .= " (MSL)" if $element eq 'SK';
         }

         $out .= "\n";
   }

   $out;
}
 
sub decode_METAR_TAF {
   my ($s, $style) = @_;
   $s = uc $s if $style;

   $s =~ s/=//g;

   my ($out) = '';

   $out = $s . "\n";

   my $id = '';
   my $token;

   my @tokens = split /\s+/, $s;

   while ($token = shift @tokens) {
         $out .= $token . "\t" if $style;

         my $intensity = substr($token, 0, 1);
         if ($intensity eq '-') {
            $intensity = 'light';
         }
         elsif ($intensity eq '+') {
            $intensity = 'heavy';
         }

         if ($intensity eq 'light' or $intensity eq 'heavy') {
            $out .= $intensity . ' ';# off for -TSRA
            $token = substr($token,1);
         }

# Part 1: Identification Section
         if ($id eq '' and $token =~ /^[A-Z]{4}$/) {
            $id = $token;
            $out .= "for airport " . $token;
         }
         elsif ($token =~ /^(\d{2})(\d{2})(\d{2})Z$/) {
            $out .= "issued day $1 at $2:$3 zulu";
         }
         elsif ($token =~ /^(\d{2})(\d{2})(\d{2})$/) {
            $out .= "valid from day $1 at $2:00 to $3:00 zulu";
         }
# Part 2: Observations Section
         elsif ($token =~ /^00000KT$/) {
            $out .= "wind light and variable";
         }
         elsif ($token =~ /^VRB(\d{2})KT$/) {
            $out .= "variable wind direction at @{[int $1]} knots";
         }
         elsif ($token =~ /^(\d{3})V(\d{3})$/) {
            $out .= "wind varies from $1 to $2";
         }
         elsif ($token =~ /^(\d{3})(\d{2})(G?)(\d+)?KT$/) {
            $out .= "wind from $1 true at @{[int $2]} knots";
            $out .= " gusts to $4" if $3 eq 'G';
         }
         elsif ($token =~ /^(\d{1,2})$/) {
            $out .= "ground visibility $1";
            if ($token = shift @tokens) {
               if ($token =~ /^(\d+\/\d+)$/) {
                  $out .= " and $1 statute miles";
               }
            }
         }
         elsif ($token =~ /^(P?)(\d+)SM$/) {
            $out .= "ground visibility @{[$1 eq 'P'?'more than ':'']}$2 statute miles";
         }
         elsif ($token =~ /^(\d+)\/(\d+)SM$/) {
            $out .= "ground visibility $1/$2 statute miles	";
         }
         elsif ($token =~ /^R(\d{2})(L|C|R)\/(M|P)?(\d+)FT$/) {
            $out .= "runway visibility for Rwy $1$2 is @{[$3 eq 'M'?'less than minimum of ':'']}@{[$3 eq 'M'?'more than maximum of ':'']}$4 feet";
         }
         elsif ($token =~ /^HZ$/) {
            $out .= "weather hazard (or maybe just haze)";
         }
# Part 3: Gauge Readings
         elsif ($token =~ /^(M?)(\d{2,3})\/(M?)(\d{2,3})$/) {
            $out .= "temperature @{[$1?'-':'']}@{[int($2)]} Celsius, dew point @{[$3?'-':'']}@{[int($4)]} Celsius.";
         }
         elsif ($token =~ /^A(\d{2})(\d{2})$/) {
            $out .= "altimeter setting $1.$2 inches mercury";
         }
         elsif ($token =~ /^Q(\d{3})(\d)$/) {
            $out .= "altimeter setting $1.$2 hectopascals";
         }
# Part 4: Remarks and Coded Data
         elsif ($token =~ /^AO(1|2)$/) {
            $out .= "automated station type $1: @{[$1 eq '01'?'cannot detect precipitation':'has precipitation discriminator']}";
         }
         elsif ($token =~ /^P(\d{4})$/) {
            $out .= "precipitation @{[$1/100]} inches in last hour";
         }
         elsif ($token =~ /^(\d{3})(\d{2})\/(\d{2})$/) {
            $out .= "wind from $1 at $2 knots starting at $3 after the hour";
         }
         elsif ($token =~ /^1(0|1)(\d{3})$/) {
            $out .= "max temp in last 6 hours @{[$1?'-':'']}@{[$2/10]} Celsius";
         }
         elsif ($token =~ /^2(0|1)(\d{3})$/) {
            $out .= "min temp in last 6 hours @{[$1?'-':'']}@{[$2/10]} Celsius";
         }
         elsif ($token =~ /^4\/(\d{3})$/) {
            $out .= "snow depth on ground is @{[$1]} inches";
         }
         elsif ($token =~ /^5(\d)(\d{3})$/) {
            $out .= "3 hour pressure tendency ";
            if ($1 eq '4') {
               $out .= "stationary ";
            }
            elsif ($1 gt '4') {
               $out .= "decreased ";
            }
            else {
               $out .= "increased ";
            }
            $out .= $2/10 . " millibars";
         }
         elsif ($token =~ /^6(\d{4})$/) {
            $out .= "3 and 6 hour precipitation @{[$1/100]} inches";
         }
         elsif ($token =~ /^7(\d{4})$/) {
            $out .= "24 hour total precipitation @{[$1/100]} inches";
         }
         elsif ($token =~ /^8\/(\d)(\d)(\d)$/) {
            $out .= "WMO cloud types $low[$1], $middle[$2], $high[$3]";
         }
         elsif ($token =~ /^98(\d{3})$/) {
            $out .= "$1 minutes of sunshine during day";
         }
         elsif ($token =~ /^933(\d{3})$/) {
            $out .= "standing water equivalent of @{[$1/10]} inches";
         }
         elsif ($token =~ /^SLP(\d{3})$/) {
            $out .= "sea level Pressure @{[($1/10) + (($1<700)?1000:900)]} millibars";
         }
         elsif ($token =~ /^FM(\d{2})(\d{2})$/) {
            $out .= "from $1:$2 zulu";
         }
         elsif ($token =~ /^PROB(\d{2})$/) {
            $out .= "probability $1%";
         }
         elsif ($token =~ /^WS(\d{3})\/(\d{3})(\d{2,3})KT$/) { # TAF WS
            $out .= "wind shear at $1 feet from $2 degrees at $3 knots";
         }
         elsif ($token =~ /^4(\d)(\d{3})(\d)(\d{3})$/) {
            $out .= "max 6 hour temperature @{[$1?'-':'']}@{[$2/10]} Celsius, min 6 hour temp @{[$3?'-':'']}@{[$4/10]} Celsius";
         }
         elsif ($token =~ /^T(\d)(\d{3})(\d)(\d{3})$/) {
            $out .= "temperature @{[$1?'-':'']}@{[$2/10]} Celsius, dew point @{[$3?'-':'']}@{[$4/10]} Celsius";
         }
         elsif ($token =~ /^([A-Z]{2})B(\d{2})$/) {
            if (exists $abb{$1}) {
               $out .= $abb{$1} . " began at $2 minutes after the hour";
            }
            else {
               $out .= $token . "?";
            }
         }
         elsif ($token =~ /^(\d{2})(\d{2})$/) {
            $out .= "from $1:00 to $2:00";
         }
# Miscellaneous Tokens
         elsif (exists $abb{$token}) {
            $out .= $abb{$token};
         }
         elsif ($token =~ /^([A-Z]{3})([0-9]+)(CB|TCU)?(VV)?(\d{3})?$/) {
            if ($1 eq 'FEW' or $1 eq 'SCT' or $1 eq 'BKN' or $1 eq 'OVC') {
               $out .= $abb{$1} . " clouds start at @{[$2 * 100]} feet AGL";
            }
            elsif (exists $abb{$1}) {
               $out .= $abb{$1} . $2;
            }
            else {
               $out .= $token . "?";
            }

            if ($3 eq 'CB') {
               $out .= " with cumulonimbus (rain)";
            }
            elsif ($3 eq 'TCU') {
               $out .= " with towering cumulus";
            }

            if ($4 eq 'VV') {
               $out .= " vertical visibility (indefinite ceiling) $5 feet";
            }
         }
# supposed to be max 3 groups, BR should always be by itself
         elsif ($token =~ /^([A-Z]{2,})$/) {
            my $i = 0;
            my $x = '';

            foreach (split //, $1) {
                  $i++;
                  $x .= $_;

                  if ($i == 2) {
                     if (exists $abb{$x}) {
                        $out .= $abb{$x} . ' ';
                     }
                     else {
                        $out .= $x . "?";
                     }

                     $i = 0;
                     $x = '';
                  }
            }
         }
         else {
            $out .= $token . "?";
         }

         $out .= "\n";
   } 

   $out;
}
__END__

=head1 NAME

Aviation::Report - Perl extension for translating U.S. METAR, TAF and PIREP textual reports into plain English.

=head1 SYNOPSIS

  use strict;
  use Aviation::Report;

  print decode_METAR_TAF(report, style);
  print decode_PIREP(report, style);

=head1 DESCRIPTION

Translates U.S. METAR, TAF and PIREP text reports into plain English.
Although the syntax of these reports is standardized, it is not as
obvious as it first appears to make correct translations.

The style option controls the final appearance. A style of 0 emits
only plain English, while 1 includes the original tokens for
reference purposes.

=head1 AUTHOR

James Briggs <71022.3700@compuserve.com>

=head1 SEE ALSO

METAR.pm by Jeremy Zawodny

=cut
