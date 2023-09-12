#
#  ZUGLIST_DELAY.PL
#  ================
#
#  Skript zur Umwandlung der vom Matchserver geschriebenen Datei "delay_liste"
#  in eine ("delay.tpl") oder mehrere Template-Dateien.
#  Die Ausgabe der einzelnen Template-Datei erfolgt nach STDOUT.
#
#  Aufruf: perl zuglist_delay.pl <DELAY_LISTE> [-s] [-m] [-m<PFAD>]
#                                [-p] [-p<DATEI>] [-w<DATEI>]
#
#  Dateien:
#    DELAY_LISTE = Vom Matchserver erzeugte CSV-Datei "delay_liste" mit einer
#                  Liste aller verspaeteten Fahrten
#
#  Parameter:
#    -s          = Schreiben einer Statistik ueber alle empfangenen
#                  Datenquellen und Linien
#    -m          = Aufteilen der Ausgabedaten auf mehrere Template-Dateien
#    -m<PFAD>    = Wie "-m". Die Ausgabedateien werden ins Verzeichnis <Pfad>
#                  geschrieben.
#    -p          = Funkioniert nur zusammen mit Schalter "-m".
#                  Aktiviert die Ueberwachung der Datenquellen. Abhaengig von
#                  den im Hash "%lieferanten" gemachten Einstellungen werden
#                  Warnungen in eine Datei "warnmail" ausgegeben, falls eine
#                  Datenquelle eine bestimmte Zeit keine Daten sendet.
#                  Die Zeitpunkte, zu denen die einzelnen Datenquellen zuletzt
#                  Daten gesendet haben, wird beim Aufruf dieses Skripts aus
#                  der Datei "provider_status" gelesen und abschliessend auch
#                  wieder gespeichert.
#    -p<DATEI>   = Wie "-p". Die Zeitpunkte, zu denen die Datenquellen zuletzt
#                  Daten geliefert haben werden in DATEI gespeichert.
#    -w<DATEI>   = Ausgabe der Warnmeldungen fuer Modus "-p" in DATEI statt
#                  in "warnmail"
#    -g          = Gleise, die sich geaendert haben, in die Ausgabedatei
#                  schreiben
#    -gs         = Alle Gleise (auch die, die zu den Soll-Gleisen identisch
#                  sind) in die Ausgabedatei schreiben
#    -h<DATEI>   = Liest die historie der nicht gematchten RT-Infos aus DATEI
#                  und schreibt diese in die Datei "rt_trouble.tpl"
#    -t<DATEI>   = Ausgabedatei fuer die historie der nicht gematchten RT-Infos

################################################################################
################################################################################
#
#     Globale Variablen, die Versionsspezifisch angepasst werden muessen.
#
################################################################################
################################################################################

%lieferanten = (  # Definition der verfuegbaren Datenquellen (fuer Modus "-s")
                  #
                  # Komponenten:
                  # - name       : Name der Datenquelle
                  # - warn_tag   : Im Modus "-p" wird tagsueber eine Warnung
                  #                ausgegeben, falls eine die Datenquelle
                  #                warn_tag Minuten keine Daten geliefert hat.
                  #                Siehe dazu $start_tag und $ende_tag
                  # - warn_nacht : Analog dazu fuer nachts.

                1  => {
                      'name' => "DB",
                      'warn_tag' => -1,
                      'warn_nacht' => -1,
                      },
                2  => {
                      'name' => "DDIP",
                      'warn_tag' => -1,
                      'warn_nacht' => -1,
                      },
                3  => {
                      'name' => "DDIP-Test",
                      'warn_tag' => -1,
                      'warn_nacht' => -1,
                      },
                );

$warn_global = 30;        # Wenn die letzte Datenaufbereitung $warn_global
                          # Minuten zurueckliegt, wird im Modus "-p"
                          # eine globale Warn-Meldung ausgegeben.

$start_tag = 360;         # Beginn des Tagbetriebs fuer die Warnungen
$ende_tag  = 1320;        # Beginn des Nachtbetriebs fuer die Warnungen

$meldeintervall = 1440;   # Zu einem Ereignis wird innerhalb dieses 
                          # Intervalls maximal eine Meldung verschickt.

@grenzen = (2, 5, 10, 15, 20, 30); # Grenzen fuer die Ausgabe der Anzahlen
                                   # von verspaeteten Fahrten

################################################################################
################################################################################
#
#   Globale Variablen, die per Kommandozeilenparameter gesetzt werden koennen.
#
################################################################################
################################################################################

# Schalter zum Aktivieren der Statistik ueber alle Linien/Datenquellen
# --------------------------------------------------------------------
$linien_stat = 1;

# Einstellungen zu den Warnungen, die augegeben werden sollen,
# wenn eine Datenquelle eine definierte Zeit lang keine Daten sendet. 
# -------------------------------------------------------------------
$prov_check = 0;          # Aktiviert diesen Warnungsbetrieb
$prov_name = "provider_status";
$warn_name = "warnmail";  # Name der Datei mit Warnungen

# Schalter, um die Daten auf mehrere Dateien (je Datenquelle) aufzuteilen
# -----------------------------------------------------------------------
$write_multi_files = 0;
$multi_path = ".";

# Init der Daten zu den definierten Lieferanten
# ---------------------------------------------
foreach $quelle (keys %lieferanten)
    {
    $lieferanten{$quelle}{letzte_meldung} = -1;
    $lieferanten{$quelle}{letzte_warnung} = -1;
    $lieferanten{$quelle}{definiert}      = 1;
    $lieferanten{$quelle}{ANZ}            = 0;
    $lieferanten{$quelle}{DELAY}          = -1;
    $lieferanten{$quelle}{MAXDELAY}       = -1;
    foreach $gr (@grenzen)
        {
        $lieferanten{$quelle}{DELAY_GRZ}{$gr} = 0;
        }
    }

# Globale Variablen
# -----------------
@mon = (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334);

$last_systime = -1;      # Systemzeit der letzten Aufbereitung
$last_syswarn = -1;      # Letzte Warnung dazu erfolgte zu dieser Zeit
$first_systime = -1;     # Zeit des ersten Systemstarts
$write_gleise = 0;       # Gleise ausgeben
$write_same_gleise = 0;  # Auch Gleise ausgeben, die identisch zum
                         # Soll-Gleis sind.

$trouble_in = "";
$trouble_out = "rt_trouble.tpl";

# Ausgabedatei
# ------------
$MY_STDOUT = STDOUT;

################################################################################
################################################################################
#
#                       Start des eigentlichen Skripts.
#
################################################################################
################################################################################

# Kommandozeilenparameter lesen
# -----------------------------
if (@ARGV < 1)
    {
    fatal("Keine Eingabedatei definiert.");
    }

$in_name = shift @ARGV;

while ($z = shift @ARGV)
    {
    if ($z =~ /^-s/)
        {
        $linien_stat = 1;
        }
    elsif ($z =~ /^-m(.*)/)
        {
        $write_multi_files = 1;
        if ($1 ne "")
            {
            $multi_path = $1;
            }
        }
    elsif ($z =~ /^-p(.*)/)
        {
        $prov_check = 1;
        if ($1 ne "")
            {
            $prov_name = $1;
            }
        }
    elsif ($z =~ /^-w(.*)/)
        {
        $warn_name = $1;
        }
    elsif ($z =~ /^-g/)
        {
        $write_gleise = 1;
        if ($z =~ /^-gs/)
            {
            $write_same_gleise = 1;
            }
        }
    elsif ($z =~ /^-h(.*)/)
        {
        $trouble_in = $1;
        }
    elsif ($z =~ /^-t(.*)/)
        {
        $trouble_out = $1;
        }
    else
        {
        fatal("Unbekannter Kommadozeilenparameter: ".$z);
        }
    }

# Datenkonsistenz checken
# -----------------------
if ($prov_check && !$linien_stat)
    {
    fatal("Provider-Status nur in Verbindung mit Linien-Statistik erlaubt.");
    }

# Infos zu den Datenlieferanten lesen
# -----------------------------------
if ($prov_check)
    {
    read_prov_infos();
    }

# Oeffnen der Eingabedatei
# ------------------------
if (!open ($IN, $in_name))
    {
    fatal("Konnte Datei ".$in_name." nicht oeffnen.");
    }

# Zeitstempel der Daten einlesen
# ------------------------------
$zeile1 = <$IN>;
chomp($zeile1);
$zeile2 = <$IN>;
chomp($zeile2);

$systime = conv_timestring($zeile1);
if ($first_systime < 0)
    {
    $first_systime = $systime;
    }

# Einlesen der Eingabedatei (delay_liste)
# ---------------------------------------
$def_count = 0;
while(<$IN>)
    {
    s/\x0d|\x0a//g;

    $test = substr($_, 0, 1);
    if ($test eq "!")
        {
        if (/platform/)
            {
            if (/platform\.(\d+)/)
                {
                $idx = $1;
                $gl{$idx}{AN} = 0;
                $gl{$idx}{AB} = 0;
                $gl{$idx}{AN_SAME} = 0;
                $gl{$idx}{AB_SAME} = 0;
                $gl_count;
                }

            if (/same_an_gls/)
                {
                $gl{$idx}{AN_SAME} = 1;
                }
            elsif (/an_gls/)
                {
                $gl{$idx}{AN} = 1;
                }

            if (/same_ab_gls/)
                {
                $gl{$idx}{AB_SAME} = 1;
                }
            elsif (/ab_gls/)
                {
                $gl{$idx}{AB} = 1;
                }

            $gl{$idx}{LISTE}{$gl_count} = $_;
            $gl_count++;
            }
        elsif ($linien_stat && /def mstat/)
            {
            if (/def mstat_(\d+)_([^\s]+) (.*)/)
                {
                $nr = $1;
                $typ = $2;
                $val = $3;

                $provider_zus{$nr}{$typ} = $val;
                }
            }
        else
            {
            if ($linien_stat && /def glob_mstat/)
                {
                s/glob_mstat/all_providers/;
                }

            $def{$def_count} = $_;
            $def_count++;
            }
        next;
        }

    ($delay, $zeitext, $zeit, $datumext, $datum, $zugext, $zugint,
        $takt, $puic, $bhfint, $bhfext, $bhfbez, $arrival, $max_delay,
        $x, $y, $gattung, $richtung, $datum_abf, $meldezeitext, $meldezeit,
        $meldedatumext, $meldedatum, $quelle, $fahrt_id, $meldungen,
        $betr, $rt_infotexte, $startbf, $zielbf) = split /;/;

    $bhfbez =~ tr/„”Ž™šá‚Šƒ“ˆ/äöüÄÖÜßéèâôê/;

    if ($datum_abf eq "")
        {
        $tag_abf   = -1;
        $monat_abf = -1;
        $jahr_abf  = -1;
        }
    else
        {
        $datum_abf =~ m/(\d{2})\.(\d{2})\.(\d{4})/;
        $tag_abf   = $1;
        $monat_abf = $2;
        $jahr_abf  = $3;
        }

    if ($linien_stat)
        {
        $linie_bez = $zugext.";".$quelle;
        insert_linie($linie_bez);

        insert_lieferant($quelle);
        }

    $liste{$delay}{$zugint}{$takt}{$puic}{DATUMEXT}  = $datumext;
    $liste{$delay}{$zugint}{$takt}{$puic}{TAKT}      = $takt;
    $liste{$delay}{$zugint}{$takt}{$puic}{ZEITEXT}   = $zeitext;
    $liste{$delay}{$zugint}{$takt}{$puic}{BHFINT}    = $bhfint;
    $liste{$delay}{$zugint}{$takt}{$puic}{ZUGEXT}    = $zugext;
    $liste{$delay}{$zugint}{$takt}{$puic}{BHFEXT}    = $bhfext;
    $liste{$delay}{$zugint}{$takt}{$puic}{BHFBEZ}    = $bhfbez;
    $liste{$delay}{$zugint}{$takt}{$puic}{ARRIVAL}   = $arrival;
    $liste{$delay}{$zugint}{$takt}{$puic}{MAX_DELAY} = $max_delay;
    $liste{$delay}{$zugint}{$takt}{$puic}{X_KOOR}    = $x;
    $liste{$delay}{$zugint}{$takt}{$puic}{Y_KOOR}    = $y;
    $liste{$delay}{$zugint}{$takt}{$puic}{GATTUNG}   = $gattung;
    $liste{$delay}{$zugint}{$takt}{$puic}{RICHTUNG}  = $richtung;
    $liste{$delay}{$zugint}{$takt}{$puic}{TAG_ABF}   = $tag_abf;
    $liste{$delay}{$zugint}{$takt}{$puic}{MONAT_ABF} = $monat_abf;
    $liste{$delay}{$zugint}{$takt}{$puic}{JAHR_ABF}  = $jahr_abf;
    $liste{$delay}{$zugint}{$takt}{$puic}{MDATUMEXT} = $meldedatumext;
    $liste{$delay}{$zugint}{$takt}{$puic}{MZEITEXT}  = $meldezeitext;
    $liste{$delay}{$zugint}{$takt}{$puic}{QUELLE}    = $quelle;
    $liste{$delay}{$zugint}{$takt}{$puic}{FAHRT_ID}  = $fahrt_id;
    $liste{$delay}{$zugint}{$takt}{$puic}{MELDUNGEN} = $meldungen;
    $liste{$delay}{$zugint}{$takt}{$puic}{BETR}      = $betr;
    $liste{$delay}{$zugint}{$takt}{$puic}{RT_INFOTEXTE} = $rt_infotexte;
    $liste{$delay}{$zugint}{$takt}{$puic}{STARTBF}   = $startbf;
    $liste{$delay}{$zugint}{$takt}{$puic}{ZIELBF}    = $zielbf;

    $quellen{$quelle} = 1;
    }

# Oeffnen der Ausgabedateien
# --------------------------
if ($write_multi_files)
    {
    foreach $quelle (keys %quellen)
        {
        $dateiname = ">".$multi_path."/delay_del_q".$quelle.".tpl";
        if (!open $DAT_DEL{$quelle}, $dateiname)
            {
            fatal("Konnte Datei ".$dateiname." nicht oeffnen.");
            }
        $dateiname = ">".$multi_path."/delay_pkt_q".$quelle.".tpl";
        if (!open $DAT_PKT{$quelle}, $dateiname)
            {
            fatal("Konnte Datei ".$dateiname." nicht oeffnen.");
            }

        $OUT = $DAT_DEL{$quelle};
        printf $OUT "!def delay_systime %s\n", $zeile1;
        printf $OUT "!def delay_rawtime %s\n", $zeile2;

        $OUT = $DAT_PKT{$quelle};
        printf $OUT "!def delay_systime %s\n", $zeile1;
        printf $OUT "!def delay_rawtime %s\n", $zeile2;
        }

    $dateiname = ">".$multi_path."/delay_rest.tpl";
    if (!open $REST, $dateiname)
        {
        fatal("Konnte Datei ".$dateiname." nicht oeffnen.");
        }
    printf $REST "!def delay_systime %s\n", $zeile1;
    printf $REST "!def delay_rawtime %s\n", $zeile2;

    $dateiname = ">".$multi_path."/delay_gleise.tpl";
    if (!open $GLEISE, $dateiname)
        {
        fatal("Konnte Datei ".$dateiname." nicht oeffnen.");
        }
    printf $GLEISE "!def delay_systime %s\n", $zeile1;
    printf $GLEISE "!def delay_rawtime %s\n", $zeile2;

    if ($linien_stat)
        {
        $dateiname = ">".$multi_path."/delay_provider.tpl";
        if (!open $PROV, $dateiname)
            {
            fatal("Konnte Datei ".$dateiname." nicht oeffnen.");
            }
        printf $PROV "!def delay_systime %s\n", $zeile1;
        printf $PROV "!def delay_rawtime %s\n", $zeile2;

        $dateiname = ">".$multi_path."/delay_line.tpl";
        if (!open $LINE, $dateiname)
            {
            fatal("Konnte Datei ".$dateiname." nicht oeffnen.");
            }
        printf $LINE "!def delay_systime %s\n", $zeile1;
        printf $LINE "!def delay_rawtime %s\n", $zeile2;

        $dateiname = ">".$multi_path."/delay_line_g1.tpl";
        if (!open $LINE_G1, $dateiname)
            {
            fatal("Konnte Datei ".$dateiname." nicht oeffnen.");
            }
        printf $LINE_G1 "!def delay_systime %s\n", $zeile1;
        printf $LINE_G1 "!def delay_rawtime %s\n", $zeile2;
        }
    }

printf $MY_STDOUT "!def delay_systime %s\n", $zeile1;
printf $MY_STDOUT "!def delay_rawtime %s\n", $zeile2;

$i = 0;

foreach $delay (sort ab_num keys %liste)
    {
    # Auf alle Faelle Anzahl der Verspaetungen >= 1 schreiben
    # -------------------------------------------------------
    if ($delay == 0 && !(exists $liste{1}))
        {
        printf $MY_STDOUT "!def delay_1_num %d\n", $i - 1;
        }

    foreach $zugint (sort keys %{$liste{$delay}})
        {
        foreach $takt (sort keys %{$liste{$delay}{$zugint}})
            {
            foreach $puic (sort keys %{$liste{$delay}{$zugint}{$takt}})
                {
                $datumext      = $liste{$delay}{$zugint}{$takt}{$puic}{DATUMEXT};
                $takt          = $liste{$delay}{$zugint}{$takt}{$puic}{TAKT};
                $zeitext       = $liste{$delay}{$zugint}{$takt}{$puic}{ZEITEXT};
                $bhfint        = $liste{$delay}{$zugint}{$takt}{$puic}{BHFINT};
                $zugext        = $liste{$delay}{$zugint}{$takt}{$puic}{ZUGEXT};
                $bhfext        = $liste{$delay}{$zugint}{$takt}{$puic}{BHFEXT};
                $bhfbez        = $liste{$delay}{$zugint}{$takt}{$puic}{BHFBEZ};
                $arrival       = $liste{$delay}{$zugint}{$takt}{$puic}{ARRIVAL};
                $max_delay     = $liste{$delay}{$zugint}{$takt}{$puic}{MAX_DELAY};
                $x             = $liste{$delay}{$zugint}{$takt}{$puic}{X_KOOR};
                $y             = $liste{$delay}{$zugint}{$takt}{$puic}{Y_KOOR};
                $gattung       = $liste{$delay}{$zugint}{$takt}{$puic}{GATTUNG};
                $richtung      = $liste{$delay}{$zugint}{$takt}{$puic}{RICHTUNG};
                $tag_abf       = $liste{$delay}{$zugint}{$takt}{$puic}{TAG_ABF};
                $monat_abf     = $liste{$delay}{$zugint}{$takt}{$puic}{MONAT_ABF};
                $jahr_abf      = $liste{$delay}{$zugint}{$takt}{$puic}{JAHR_ABF};
                $meldedatumext = $liste{$delay}{$zugint}{$takt}{$puic}{MDATUMEXT};
                $meldezeitext  = $liste{$delay}{$zugint}{$takt}{$puic}{MZEITEXT};
                $quelle        = $liste{$delay}{$zugint}{$takt}{$puic}{QUELLE};
                $fahrt_id      = $liste{$delay}{$zugint}{$takt}{$puic}{FAHRT_ID};
                $meldungen     = $liste{$delay}{$zugint}{$takt}{$puic}{MELDUNGEN};
                $betr          = $liste{$delay}{$zugint}{$takt}{$puic}{BETR};
                $rt_infotexte  = $liste{$delay}{$zugint}{$takt}{$puic}{RT_INFOTEXTE};
                $startbf       = $liste{$delay}{$zugint}{$takt}{$puic}{STARTBF};
                $zielbf        = $liste{$delay}{$zugint}{$takt}{$puic}{ZIELBF};
                printf $MY_STDOUT "!def delay.%d %d\n", $i, $delay;
                printf $MY_STDOUT "!def delay_%d_time %s\n", $i, $zeitext;
                printf $MY_STDOUT "!def delay_%d_date %s\n", $i, $datumext;
                printf $MY_STDOUT "!def delay_%d_station_name %s\n", $i, $bhfbez;
                printf $MY_STDOUT "!def delay_%d_station_id %s\n", $i, $bhfext;
                printf $MY_STDOUT "!def delay_%d_train_name %s\n", $i, $zugext;
                printf $MY_STDOUT "!def delay_%d_train_id %s\n", $i, $zugint;
                printf $MY_STDOUT "!def delay_%d_train_cycle %s\n", $i, $takt;
                printf $MY_STDOUT "!def delay_%d_train_puic %s\n", $i, $puic;
                printf $MY_STDOUT "!def delay_%d_train_arrival %s\n", $i, $arrival;
                printf $MY_STDOUT "!def delay_%d_max_delay %s\n", $i, $max_delay;
                printf $MY_STDOUT "!def delay_%d_x_koor %s\n", $i, $x;
                printf $MY_STDOUT "!def delay_%d_y_koor %s\n", $i, $y;
                printf $MY_STDOUT "!def delay_%d_gattung %ld\n", $i, $gattung;
                printf $MY_STDOUT "!def delay_%d_richtung %ld\n", $i, $richtung;
                printf $MY_STDOUT "!def delay_%d_tag_abf %ld\n", $i, $tag_abf;
                printf $MY_STDOUT "!def delay_%d_monat_abf %ld\n", $i, $monat_abf;
                printf $MY_STDOUT "!def delay_%d_jahr_abf %ld\n", $i, $jahr_abf;
                printf $MY_STDOUT "!def delay_%d_reporttime %s\n", $i, $meldezeitext;
                printf $MY_STDOUT "!def delay_%d_reportdate %s\n", $i, $meldedatumext;
                printf $MY_STDOUT "!def delay_%d_source %s\n", $i, $quelle;
                printf $MY_STDOUT "!def delay_%d_service_id %s\n", $i, $fahrt_id;
                printf $MY_STDOUT "!def delay_%d_reports %s\n", $i, $meldungen;
                printf $MY_STDOUT "!def delay_%d_operator %s\n", $i, $betr;
                printf $MY_STDOUT "!def delay_%d_rt_infotexte %s\n", $i, $rt_infotexte;
                printf $MY_STDOUT "!def delay_%d_start_name %s\n", $i, $startbf;
                printf $MY_STDOUT "!def delay_%d_dest_name %s\n", $i, $zielbf;
        
                if ($write_multi_files)
                    {
                    if ($delay == 0)
                        {
                        $OUT = $DAT_PKT{$quelle};
                        }
                    else
                        {
                        $OUT = $DAT_DEL{$quelle};
                        }

                    printf $OUT "!def delay.%d %d\n", $i, $delay;
                    printf $OUT "!def delay_%d_time %s\n", $i, $zeitext;
                    printf $OUT "!def delay_%d_date %s\n", $i, $datumext;
                    printf $OUT "!def delay_%d_station_name %s\n", $i, $bhfbez;
                    printf $OUT "!def delay_%d_station_id %s\n", $i, $bhfext;
                    printf $OUT "!def delay_%d_train_name %s\n", $i, $zugext;
                    printf $OUT "!def delay_%d_train_id %s\n", $i, $zugint;
                    printf $OUT "!def delay_%d_train_cycle %s\n", $i, $takt;
                    printf $OUT "!def delay_%d_train_puic %s\n", $i, $puic;
                    printf $OUT "!def delay_%d_train_arrival %s\n", $i, $arrival;
                    printf $OUT "!def delay_%d_max_delay %s\n", $i, $max_delay;
                    printf $OUT "!def delay_%d_x_koor %s\n", $i, $x;
                    printf $OUT "!def delay_%d_y_koor %s\n", $i, $y;
                    printf $OUT "!def delay_%d_gattung %ld\n", $i, $gattung;
                    printf $OUT "!def delay_%d_richtung %ld\n", $i, $richtung;
                    printf $OUT "!def delay_%d_tag_abf %ld\n", $i, $tag_abf;
                    printf $OUT "!def delay_%d_monat_abf %ld\n", $i, $monat_abf;
                    printf $OUT "!def delay_%d_jahr_abf %ld\n", $i, $jahr_abf;
                    printf $OUT "!def delay_%d_reporttime %s\n", $i, $meldezeitext;
                    printf $OUT "!def delay_%d_reportdate %s\n", $i, $meldedatumext;
                    printf $OUT "!def delay_%d_source %s\n", $i, $quelle;
                    printf $OUT "!def delay_%d_service_id %s\n", $i, $fahrt_id;
                    printf $OUT "!def delay_%d_reports %s\n", $i, $meldungen;
                    printf $OUT "!def delay_%d_operator %s\n", $i, $betr;
                    printf $OUT "!def delay_%d_rt_infotexte %s\n", $i, $rt_infotexte;
                    printf $OUT "!def delay_%d_start_name %s\n", $i, $startbf;
                    printf $OUT "!def delay_%d_dest_name %s\n", $i, $zielbf;
                    }
        
                $i++;
                }
            }
        }
    printf $MY_STDOUT "!def delay_%d_num %d\n", $delay, $i-1;
    }

# Auf alle Faelle Anzahl der Verspaetungen >= 1 schreiben
# -------------------------------------------------------
if (!(exists $liste{0}) && !(exists $liste{1}))
    {
    printf $MY_STDOUT "!def delay_1_num %d\n", $i - 1;
    }

printf $MY_STDOUT "!def delay_num %d\n", $i-1;

foreach $def_count (sort auf_num keys %def)
    {
    printf $MY_STDOUT "%s\n", $def{$def_count};
    if ($write_multi_files)
        {
        printf $REST "%s\n", $def{$def_count};
        }
    }

if ($write_gleise)
    {
    foreach $idx (sort auf_num keys %gl)
        {
        if (!$write_same_gleise
                && (!$gl{$idx}{AN} || $gl{$idx}{AN_SAME})
                && (!$gl{$idx}{AB} || $gl{$idx}{AB_SAME}))
            {
            next;
            }

        foreach $gl_count (sort auf_num keys %{$gl{$idx}{LISTE}})
            {
            printf $MY_STDOUT "%s\n", $gl{$idx}{LISTE}{$gl_count};
            if ($write_multi_files)
                {
                printf $GLEISE "%s\n", $gl{$idx}{LISTE}{$gl_count};
                }
            }
        }
    }

if ($linien_stat)
    {
    # Ausgabe sortiert nach Anzahl ueberwachter Fahrten
    # -------------------------------------------------
    $i = 0;
    foreach $linie_bez (sort {$linien{$b}{ANZ} <=> $linien{$a}{ANZ}} keys %linien)
        {
        $linie_bez =~ /(.*);(\d*)/;

        $quelle = $2;
        $zugext = $1;

        print_linie($linie_bez, $quelle, $zugext, $i, $MY_STDOUT);
        if ($write_multi_files)
            {
            print_linie($linie_bez, $quelle, $zugext, $i, $LINE);
            if ($linien{$linie_bez}{ANZ} > 1)
                {
                print_linie($linie_bez, $quelle, $zugext, $i, $LINE_G1);
                }
            }
        $i++;
        }
    $i = 0;
    insert_zus_lieferanten();
    foreach $quelle (sort {$lieferanten{$b}{ANZ} <=> $lieferanten{$a}{ANZ}} keys %lieferanten)
        {
        print_lieferant($quelle, $i, $MY_STDOUT);
        if ($write_multi_files)
            {
            print_lieferant($quelle, $i, $PROV);
            }
        $i++;
        }

    # Sortierung nach Linien
    # ----------------------
    $i = 0;
    foreach $linie_bez (sort keys %linien)
        {
        printf $MY_STDOUT "!def line_sort.%d %d\n", $i, $linien{$linie_bez}{NR};
        if ($write_multi_files)
            {
            printf $LINE "!def line_sort.%d %d\n", $i, $linien{$linie_bez}{NR};
            if ($linien{$linie_bez}{ANZ} > 1)
                {
                printf $LINE_G1 "!def line_sort.%d %d\n", $i, $linien{$linie_bez}{NR};
                }
            }
        $i++;
        }
    $i = 0;
    foreach $quelle (sort keys %lieferanten)
        {
        next if ($lieferanten{$quelle}{ANZ} == 0);

        printf $MY_STDOUT "!def provider_sort.%d %d\n", $i, $lieferanten{$quelle}{NR};
        if ($write_multi_files)
            {
            printf $PROV "!def provider_sort.%d %d\n", $i, $lieferanten{$quelle}{NR};
            }
        $i++;
        }

    # Sortierung nach maximaler Verspaetung
    # -------------------------------------
    $i = 0;
    foreach $linie_bez (sort {$linien{$b}{MAXDELAY} <=> $linien{$a}{MAXDELAY}} keys %linien)
        {
        printf $MY_STDOUT "!def line_sort_max_delay.%d %d\n", $i, $linien{$linie_bez}{NR};
        if ($write_multi_files)
            {
            printf $LINE "!def line_sort_max_delay.%d %d\n", $i, $linien{$linie_bez}{NR};
            if ($linien{$linie_bez}{ANZ} > 1)
                {
                printf $LINE_G1 "!def line_sort_max_delay.%d %d\n", $i, $linien{$linie_bez}{NR};
                }
            }
        $i++;
        }
    $i = 0;
    foreach $quelle (sort {$lieferanten{$b}{MAXDELAY} <=> $lieferanten{$a}{MAXDELAY}} keys %lieferanten)
        {
        next if ($lieferanten{$quelle}{ANZ} == 0);

        printf $MY_STDOUT "!def provider_sort_max_delay.%d %d\n", $i, $lieferanten{$quelle}{NR};
        if ($write_multi_files)
            {
            printf $PROV "!def provider_sort_max_delay.%d %d\n", $i, $lieferanten{$quelle}{NR};
            }
        $i++;
        }

    # Sortierung nach mittlerer Verspaetung
    # -------------------------------------
    $i = 0;
    foreach $linie_bez (sort {$linien{$b}{AVDELAY} <=> $linien{$a}{AVDELAY}} keys %linien)
        {
        printf $MY_STDOUT "!def line_sort_av_delay.%d %d\n", $i, $linien{$linie_bez}{NR};
        if ($write_multi_files)
            {
            printf $LINE "!def line_sort_av_delay.%d %d\n", $i, $linien{$linie_bez}{NR};
            if ($linien{$linie_bez}{ANZ} > 1)
                {
                printf $LINE_G1 "!def line_sort_av_delay.%d %d\n", $i, $linien{$linie_bez}{NR};
                }
            }
        $i++;
        }
    $i = 0;
    foreach $quelle (sort {$lieferanten{$b}{AVDELAY} <=> $lieferanten{$a}{AVDELAY}} keys %lieferanten)
        {
        next if ($lieferanten{$quelle}{ANZ} == 0);

        printf $MY_STDOUT "!def provider_sort_av_delay.%d %d\n", $i, $lieferanten{$quelle}{NR};
        if ($write_multi_files)
            {
            printf $PROV "!def provider_sort_av_delay.%d %d\n", $i, $lieferanten{$quelle}{NR};
            }
        $i++;
        }


    }

# Checken, ob zu einer Datenquelle Warnungen ausgegeben werden muessen.
# ---------------------------------------------------------------------
if ($prov_check)
    {
    check_prov_infos();
    write_prov_infos();
    }

if ($trouble_in ne "")
    {
    process_rt_hist_log();
    }


################################################################################
################################################################################
#
#                                 Funktionen
#
################################################################################
################################################################################


# Einen neuen Linie in die Liste aufnehmen.
# =========================================

sub insert_linie()
{
    my ($linie_bez) = @_;

    # Falls die Linie noch nicht bekannt ist, wird ein neuer Eintrag angelegt
    # -----------------------------------------------------------------------
    if (!exists $linien{$linie_bez})
        {
        $linien{$linie_bez}{ANZ}       = 0;
        $linien{$linie_bez}{DELAY}     = 0;
        $linien{$linie_bez}{MAXDELAY}  = 0;
        $linien{$linie_bez}{MDATUM}    = $meldedatum;
        $linien{$linie_bez}{MZEIT}     = $meldezeit;
        $linien{$linie_bez}{MDATUMEXT} = $meldedatumext;
        $linien{$linie_bez}{MZEITEXT}  = $meldezeitext;

        foreach $gr (@grenzen)
            {
            $linien{$linie_bez}{DELAY_GRZ}{$gr} = 0;
            }
        }

    # Meldezeit aktualisieren, falls die eingegangene Meldung neuer ist.
    # ------------------------------------------------------------------
    if ($linien{$linie_bez}{MDATUM} < $meldedatum
            || ($linien{$linie_bez}{MDATUM} == $meldedatum
                && $linien{$linie_bez}{MZEIT} < $meldezeit))
        {
        $linien{$linie_bez}{MDATUM}    = $meldedatum;
        $linien{$linie_bez}{MZEIT}     = $meldezeit;
        $linien{$linie_bez}{MDATUMEXT} = $meldedatumext;
        $linien{$linie_bez}{MZEITEXT}  = $meldezeitext;
        }

    # Anzahlen und Verspaetungen aktualisieren
    # ----------------------------------------
    $linien{$linie_bez}{ANZ}++;

    if ($linien{$linie_bez}{MAXDELAY} < $delay)
        {
        $linien{$linie_bez}{MAXDELAY} = $delay;
        }

    foreach $gr (@grenzen)
        {
        if ($delay <= $gr)
            {
            $linien{$linie_bez}{DELAY_GRZ}{$gr}++;
            }
        }

    $linien{$linie_bez}{DELAY}       += $delay;
    $linien{$linie_bez}{ZUGINT}       = $zugint;
    $linien{$linie_bez}{TAKT}         = $takt;
    $linien{$linie_bez}{PUIC}         = $puic;
    $linien{$linie_bez}{RT_INFOTEXTE} = $rt_infotexte;
}


# Schreiben aller Infos zu einer Linie
# ====================================

sub print_linie()
{
    my ($linie_bez, $quelle, $zugext, $i, $OUT) = @_;

    $linien{$linie_bez}{NR} = $i;

    $anz           = $linien{$linie_bez}{ANZ};
    $maxdelay      = $linien{$linie_bez}{MAXDELAY};
    $delay         = int($linien{$linie_bez}{DELAY} / $anz + 0.5);
    $zugint        = $linien{$linie_bez}{ZUGINT};
    $takt          = $linien{$linie_bez}{TAKT};
    $puic          = $linien{$linie_bez}{PUIC};
    $rt_infotexte  = $linien{$linie_bez}{RT_INFOTEXTE};
    $meldedatumext = $linien{$linie_bez}{MDATUMEXT};
    $meldezeitext  = $linien{$linie_bez}{MZEITEXT};
    $meldedatum    = $linien{$linie_bez}{MDATUM};
    $meldezeit     = $linien{$linie_bez}{MZEIT};

    $linien{$linie_bez}{AVDELAY} = $delay;

    printf $OUT "!def line.%d %s\n", $i, $zugext;
    printf $OUT "!def line_%d_source %s\n", $i, $lieferanten{$quelle}{name};
    printf $OUT "!def line_%d_count %ld\n", $i, $anz;
    printf $OUT "!def line_%d_max_delay %ld\n", $i, $maxdelay;
    printf $OUT "!def line_%d_av_delay %ld\n", $i, $delay;
    printf $OUT "!def line_%d_train_id %s\n", $i, $zugint;
    printf $OUT "!def line_%d_train_cycle %s\n", $i, $takt;
    printf $OUT "!def line_%d_train_puic %s\n", $i, $puic;
    printf $OUT "!def line_%d_rt_infotexte %s\n", $i, $rt_infotexte;
    printf $OUT "!def line_%d_reporttime %s\n", $i, $meldezeitext;
    printf $OUT "!def line_%d_reportdate %s\n", $i, $meldedatumext;

    foreach $gr (@grenzen)
        {
        $anz_gr = $linien{$linie_bez}{DELAY_GRZ}{$gr};

        printf $OUT "!def line_%d_delay_int.%d %d\n", $i, $gr, $anz_gr;
        printf $OUT "!def line_%d_delay_int_%d_proz %d\n", $i, $gr, ($anz_gr / $anz * 100);
        }
}


# Einen neuen Datenlieferanten in die Liste aufnehmen.
# ====================================================

sub insert_lieferant()
{
    my ($quelle) = @_;

    # Falls die Quelle noch nicht bekannt ist,
    # wird dafuer eine Dummy-Quelle aufgenommen.
    # ------------------------------------------
    if (!exists $lieferanten{$quelle})
        {
        $lieferanten{$quelle}{name}           = sprintf "Source %d", $quelle;
        $lieferanten{$quelle}{warn_tag}       = -1;
        $lieferanten{$quelle}{warn_nacht}     = -1;
        $lieferanten{$quelle}{letzte_meldung} = -1;
        $lieferanten{$quelle}{letzte_warnung} = -1;
        $lieferanten{$quelle}{definiert}      = 0;
        $lieferanten{$quelle}{ANZ}            = 0;
        $lieferanten{$quelle}{DELAY}          = -1;
        $lieferanten{$quelle}{MAXDELAY}       = -1;
        foreach $gr (@grenzen)
            {
            $lieferanten{$quelle}{DELAY_GRZ}{$gr} = 0;
            }
        }

    # Meldezeit aktualisieren, falls die eingegangene Meldung neuer ist.
    # ------------------------------------------------------------------
    $meldezeit = conv_timestring($meldezeitext." ".$meldedatumext);
    if ($meldezeit > $lieferanten{$quelle}{letzte_meldung})
        {
        $lieferanten{$quelle}{letzte_meldung} = $meldezeit;
        }

    # Anzahlen und Verspaetungen aktualisieren
    # ----------------------------------------
    $lieferanten{$quelle}{ANZ}++;
    $lieferanten{$quelle}{DELAY} += $delay;
    if ($lieferanten{$quelle}{MAXDELAY} < $delay)
        {
        $lieferanten{$quelle}{MAXDELAY} = $delay;
        }

    foreach $gr (@grenzen)
        {
        if ($delay <= $gr)
            {
            $lieferanten{$quelle}{DELAY_GRZ}{$gr}++;
            }
        }
}


# Alle Lieferanten, fuer den in der letzten Stunde Daten geliefert wurden,
# fuer die aber aktuelle keine Fahrten gematch sind, in die Liste aufnehmen.
# ==========================================================================

sub insert_zus_lieferanten()
{
    foreach $quelle (keys %provider_zus)
        {
        # Nur Lieferanten aufnehmen, die noch nicht bekannt sind.
        # -------------------------------------------------------
        next if (exists $lieferanten{$quelle});

        $lieferanten{$quelle}{name}           = sprintf "Source %d", $quelle;
        $lieferanten{$quelle}{warn_tag}       = -1;
        $lieferanten{$quelle}{warn_nacht}     = -1;
        $lieferanten{$quelle}{letzte_meldung} = -1;
        $lieferanten{$quelle}{letzte_warnung} = -1;
        $lieferanten{$quelle}{definiert}      = 0;
        $lieferanten{$quelle}{ANZ}            = 0;
        $lieferanten{$quelle}{DELAY}          = -1;
        $lieferanten{$quelle}{MAXDELAY}       = -1;
        foreach $gr (@grenzen)
            {
            $lieferanten{$quelle}{DELAY_GRZ}{$gr} = 0;
            }
        }
}

# Schreiben aller Infos zu einem Provider
# =======================================

sub print_lieferant()
{
    my ($quelle, $i, $OUT) = @_;

    $lieferanten{$quelle}{NR} = $i;

    $name          = $lieferanten{$quelle}{name};
    $anz           = $lieferanten{$quelle}{ANZ};

    printf $OUT "!def provider.%d %s\n", $i, $name;
    if ($anz == 0)
        {
        printf $OUT "!def provider_%d_used 0\n", $i;
        $linien{$linie_bez}{AVDELAY} = 0;
        }
    else
        {
        $meldung_int = $lieferanten{$quelle}{letzte_meldung};
        $meldung_ext = get_timestring($meldung_int);
        ($meldezeitext, $meldedatumext) = split /\s+/, $meldung_ext;

        $delay = int($lieferanten{$quelle}{DELAY} / $anz + 0.5);
        $maxdelay = $lieferanten{$quelle}{MAXDELAY};
        $lieferanten{$quelle}{AVDELAY} = $delay;

        printf $OUT "!def provider_%d_used 1\n", $i;
        printf $OUT "!def provider_%d_count %ld\n", $i, $anz;
        printf $OUT "!def provider_%d_max_delay %ld\n", $i, $maxdelay;
        printf $OUT "!def provider_%d_av_delay %ld\n", $i, $delay;
        printf $OUT "!def provider_%d_reporttime %s\n", $i, $meldezeitext;
        printf $OUT "!def provider_%d_reportdate %s\n", $i, $meldedatumext;

        foreach $gr (@grenzen)
            {
            $anz_gr = $lieferanten{$quelle}{DELAY_GRZ}{$gr};

            printf $OUT "!def provider_%d_delay_int.%d %d\n", $i, $gr, $anz_gr;
            printf $OUT "!def provider_%d_delay_int_%d_proz %d\n", $i, $gr, ($anz_gr / $anz * 100);
            }
        }

    if (exists $provider_zus{$quelle})
        {
        printf $OUT "!def provider_%d_data %d\n", $i,
                    $provider_zus{$quelle}{"data"};
        printf $OUT "!def provider_%d_match %d\n", $i,
                    $provider_zus{$quelle}{"match"};
        printf $OUT "!def provider_%d_proz_match %s\n", $i,
                    $provider_zus{$quelle}{"proz_match"};
        }
    else
        {
        printf $OUT "!def provider_%d_data 0\n", $i;
        printf $OUT "!def provider_%d_match 0\n", $i;
        printf $OUT "!def provider_%d_proz_match 0.0\n", $i;
        }
}


# Lesen aller Infos zu den bekannten Datenquellen
# ===============================================

sub read_prov_infos()

{
    my $IN;

    if (!open ($IN, $prov_name))
        {
        close ($IN);
        return;
        }

    # Zeit der letzten Datenaufbereitung lesen
    # ----------------------------------------
    $line = <$IN>;
    $line =~ s/\x0d|\x0a//g;
    ($quelle, $erste_meldung, $letzte_meldung, $letzte_warnung) = split /;/, $line;
    if ($quelle ne "Global")
        {
        close ($IN);
        return;
        }
    $first_systime = conv_timestring($erste_meldung);
    $last_systime  = conv_timestring($letzte_meldung);
    $last_syswarn  = conv_timestring($letzte_warnung);

    # Zeit der letzten Datenlieferung der einzelnen Quellen lesen
    # -----------------------------------------------------------
    while (<$IN>)
        {
        s/\x0d|\x0a//g;

        ($quelle, $name, $letzte_meldung, $letzte_warnung) = split /;/;

        next unless (exists $lieferanten{$quelle}
                        && $lieferanten{$quelle}{name} eq $name);

        $lieferanten{$quelle}{letzte_meldung} = conv_timestring($letzte_meldung);
        $lieferanten{$quelle}{letzte_warnung} = conv_timestring($letzte_warnung);
        }

    close ($IN);
}


# Testet, ob zu bestimmten Lieferanten Warnungen verschickt werden muessen
# ========================================================================

sub check_prov_infos()
{

    if (($systime % 1440) >= $start_tag && ($systime % 1440) <= $ende_tag)
        {
        $modus = 'warn_tag';
        }
    else
        {
        $modus = 'warn_nacht';
        }

    # Warnung ausgeben, falls die letzte Datenlieferung sehr lange zurueckliegt.
    # --------------------------------------------------------------------------
    if ($last_systime > 0 && $systime > $last_systime + $warn_global)
        {
        if ($last_syswarn < 0 || $systime > $last_syswarn + $meldeintervall)
            {
            send_warning("Seit ".get_timestring($last_systime)." keine Datenaufbereitung.");

            $first_systime = $systime;
            $last_syswarn  = $systime;
            foreach $quelle (keys %lieferanten)
                {
                $lieferanten{$quelle}{letzte_warnung} = $systime;
                }
            }

        return;
        }

    # Checken, ob fuer bestimmte Quelle eine 
    # bestimmte Zeit lang keine Daten geliefert wurden.
    # -------------------------------------------------
    foreach $quelle (keys %lieferanten)
        {
        next unless ($lieferanten{$quelle}{definiert});

        next if ($lieferanten{$quelle}{$modus} < 0);

        # Nicht warnen, wenn innerhalb eines gegebenen
        # Zeitintervalls bereits gewarnt wurde.
        # --------------------------------------------
        next if ($systime <= $lieferanten{$quelle}{letzte_warnung}
                                + $meldeintervall);

        # Ausgabe, falls die letzte Lieferung zu lange zurueckliegt.
        # ----------------------------------------------------------
        if ($lieferanten{$quelle}{letzte_meldung} > 0
                && $systime > $lieferanten{$quelle}{letzte_meldung}
                                    + $lieferanten{$quelle}{$modus})
            {
            send_warning("Fuer die Quelle ".$lieferanten{$quelle}{name}.
                         " wurden zum letzten Mal ".
                         get_timestring($lieferanten{$quelle}{letzte_meldung}).
                         " Daten gemeldet.");

            $lieferanten{$quelle}{letzte_warnung} = $systime;
            }

        # Ausgabe, falls seit Systemstart keine Daten geliefert wurden
        # ------------------------------------------------------------
        if ($lieferanten{$quelle}{letzte_meldung} < 0
                && $systime > $first_systime + $lieferanten{$quelle}{$modus})
            {
            send_warning("Fuer die Quelle ".$lieferanten{$quelle}{name}.
                         " wurden bisher (mindestens seit ".
                         get_timestring($first_systime).
                         ") keine Daten gemeldet.");

            $lieferanten{$quelle}{letzte_warnung} = $systime;
            }
        }
}


# Ausgabe der Warnungen in eine Datei
# ===================================

sub send_warning()
{
    (my $text) = @_;
    my $OUT;

    $dateiname = ">>".$warn_name;
    if (!open ($OUT, $dateiname))
        {
        fatal("Konnte Datei ".$dateiname." nicht oeffnen.");
        }

    printf $OUT "%s --- %s\n", get_timestring($systime), $text;

    close ($OUT);
}


# Schreiben aller Infos zu den bekannten Datenquellen
# ===================================================

sub write_prov_infos()

{
    my $OUT;

    $dateiname = ">".$prov_name;
    if (!open ($OUT, $dateiname))
        {
        fatal("Konnte Datei ".$dateiname." nicht oeffnen.");
        }

    printf $OUT "Global;%s;%s;%s\n",
           get_timestring($first_systime),
           get_timestring($systime),
           get_timestring($last_syswarn);

    foreach $quelle (sort auf_num keys %lieferanten)
        {
        next unless ($lieferanten{$quelle}{definiert});

        printf $OUT "%ld;%s;%s;%s\n",
               $quelle,
               $lieferanten{$quelle}{name},
               get_timestring($lieferanten{$quelle}{letzte_meldung}),
               get_timestring($lieferanten{$quelle}{letzte_warnung});
        }

    close ($OUT);
}


# Schreibt die komplette Liste der innerhalb eines 
# definierten Zeitraums nicht gematchten RT-Daten raus
# ====================================================

sub process_rt_hist_log()

{
    my $IN;
    my $OUT;

    if (!open ($IN, $trouble_in))
        {
        fatal("Konnte Datei ".trouble_in." nicht oeffnen.");
        }
    if (!open ($OUT, ">", $trouble_out))
        {
        fatal("Konnte Datei ".trouble_out." nicht oeffnen.");
        }

    $zeile = <$IN>;
    $zeile =~ s/\x0d|\x0a//g;
    printf $OUT "!def akt_systime %s\n", $zeile;

    $idx = -1;
    $lw_idx = 0;
    while (<$IN>)
        {
        s/\x0d|\x0a//g;

        if (/train_state\((\d+)\) (.*)/)
            {
            $idx++;
            $lw_idx = 0;

            $train{$idx}{STATE_ID} = $1;
            $train{$idx}{STATE} = $2;
            $train{$idx}{SORT} = -1;
            }

        next unless ($idx >= 0);

        if (/data_source (\d+)/)
            {
            $train{$idx}{SOURCE} = $1;
            }

        if (/is_matched (\d+)/)
            {
            $train{$idx}{IS_MATCHED} = $1;
            }

        if (/state_timestamp (.*)/)
            {
            $time = $1;
            $train{$idx}{STATE_TIMESTAMP} = $time;

            $min = conv_timestring($time);
            $min = $min * 10 + $train{$idx}{STATE_ID};
            if ($train{$idx}{STATE_ID} == 3)
                {
                $min -= 10000;  # Koordinatenfehler nach hinten schieben.
                }
            if ($train{$idx}{SORT} < $min)
                {
                $train{$idx}{SORT} = $min;
                }
            }

        if (/reference_date (.*)/)
            {
            $train{$idx}{REFERENCE_DATE} = $1;
            }

        if (/line\((\d+)\) (\d+) (.*)/)
            {
            $train{$idx}{LW}{$lw_idx}{TYP}    = $1;
            $train{$idx}{LW}{$lw_idx}{STATUS} = $2;
            $train{$idx}{LW}{$lw_idx}{INH}    = $3;
            $lw_idx++;
            }
        }

    $id = 0;
    foreach $idx (sort {$train{$b}{SORT} <=> $train{$a}{SORT}} keys %train)
        {
        printf $OUT "!def train.%ld %s\n", $id,
                    $train{$idx}{STATE_ID};
        printf $OUT "!def train_%ld_state %s\n", $id,
                    $train{$idx}{STATE};
        if (exists $lieferanten{$train{$idx}{SOURCE}})
            {
            printf $OUT "!def train_%ld_source %s\n", $id,
                        $lieferanten{$train{$idx}{SOURCE}}{name};
            }
        else
            {
            printf $OUT "!def train_%ld_source %s\n", $id,
                        $train{$idx}{SOURCE};
            }
        printf $OUT "!def train_%ld_source_id %s\n", $id,
                    $train{$idx}{SOURCE};

        printf $OUT "!def train_%ld_is_matched %s\n", $id,
                    $train{$idx}{IS_MATCHED};
        if (exists $train{$idx}{STATE_TIMESTAMP})
            {
            printf $OUT "!def train_%ld_state_timestamp %s\n", $id,
                        $train{$idx}{STATE_TIMESTAMP};
            }
        printf $OUT "!def train_%ld_reference_date %s\n", $id,
                    $train{$idx}{REFERENCE_DATE};

        $conv_error = 0;
        foreach $lw_idx (sort {$a <=> $b} keys %{$train{$idx}{LW}})
            {
            # Ist bereits ein fehler beim Konvertieren aufgetreten, weist die
            # Kominbation "Zeilentyp unbekannt" mit "Fehler beim Konvertieren"
            # darauf hin, dass es sich dabei nur um einen Folgefehler handelt.
            # Dieser erhaelt einen eigenen Status.
            # ----------------------------------------------------------------
            if ($conv_error
                    && $train{$idx}{LW}{$lw_idx}{TYP} == 0
                    && $train{$idx}{LW}{$lw_idx}{STATUS} == 1)
                {
                $train{$idx}{LW}{$lw_idx}{STATUS} = 32768;
                }

            printf $OUT "!def train_%ld_line.%ld %s\n", $id, $lw_idx,
                        $train{$idx}{LW}{$lw_idx}{INH};
            printf $OUT "!def train_%ld_line_%ld_typ %s\n", $id, $lw_idx,
                        $train{$idx}{LW}{$lw_idx}{TYP};
            printf $OUT "!def train_%ld_line_%ld_status %s\n", $id, $lw_idx,
                        $train{$idx}{LW}{$lw_idx}{STATUS};

            # Infos zum Aufruf der Bahhnhofstafel fuer die Halte schreiben.
            # -------------------------------------------------------------
            if ($train{$idx}{LW}{$lw_idx}{TYP} == 1
                    && $train{$idx}{LW}{$lw_idx}{INH} =~ /^(\d+)\s+\d(\d{2})(\d{2})/)
                {
                $nr = $1;
                $std = $2 % 24;
                $min = $3;

                $min += $std * 60;
                $min -= 10;
                $min = 0 if ($min < 0);

                printf $OUT "!def train_%ld_line_%ld_stop %s %.2d:%.2d\n", $id, $lw_idx,
                            $nr, int($min / 60), int($min % 60);
                }

            # Merken, ob ein Fehler beim Konvertieren aufgetreten ist.
            # --------------------------------------------------------
            if ($train{$idx}{LW}{$lw_idx}{STATUS} == 1)
                {
                $conv_error = 1;
                }
            }
        $id++;
        }

    close ($IN);
    close ($OUT);
}


# Beenden des Programms bei schweren Fehlern mit zugehoeriger Logmeldung
# ======================================================================

sub fatal()
{
    my ($s) = @_;
    my $FATAL;

    open ($FATAL, ">", "zuglist_delay.error") or die;

    printf STDERR "FATAL --- %s --- %s\n", scalar localtime(time()), $s;
    printf $FATAL "FATAL --- %s --- %s\n", scalar localtime(time()), $s;

    close ($FATAL);
    exit 1;
}


# Umwandlung des Formats SS:MM TT.MM.JJJJ in Minuten seit 1.1.1980
# ================================================================

sub conv_timestring()
{
    my ($s) = @_;

    return -1 if (!($s =~ /(\d{2}):(\d{2}) (\d{2})\.(\d{2})\.(\d{4})/));

    $std   = $1;
    $min   = $2;
    $tag   = $3;
    $monat = $4;
    $jahr  = $5;

    return (get_days($tag, $monat, $jahr) * 1440) + ($std * 60) + $min;
}


# Umwandlung von Minuten seit 1.1.1980 in das Format SS:MM TT.MM.JJJJ
# ===================================================================

sub get_timestring()
{
    my ($min) = @_;

    return "" if ($min < 0);

    $tage = int($min / 1440);
    $min %= 1440;

    $res = sprintf "%.02ld:%.02ld %s", int($min / 60), $min % 60, put_days($tage);
    return $res
}


# Umrechnung in Tage seit 1.1.1980
# ================================

sub get_days()
{
    my ($tag,             # Datum: Tag
        $monat,           # Datum: Monat
        $jahr) = @_;      # Datum: Jahr
                          # 
    my  $days;            # Dort wird das Ergebnis gesammelt
    my  $j;               # Arbeitsvar fuer das Jahr

    $jahr -= 1900 if ($jahr >= 1900);  # Abgleich bei 19..

    $j = $jahr - 80;                   # 1980 abziehen
    $j += 100 if ($j < 0);             # jahr also >= 2000

    $days = $j * 365;
    $days+= int (($j + 3) / 4);        # Anzahl Schaltjahre (richtig so?)
    $days+= $mon[$monat - 1];          # Tage der Monate dazu
    $days++ if ($monat > 2 && ($j % 4) == 0);   # mom. Jahr auch Schaltjahr
    $days+= $tag;
    return $days;
}


# Schreibt das Datum in Tagen seit 1.1.1980 als Klartext
# ======================================================

sub put_days()

{
    my ($days) = @_;     # Die Tage seit dem 1.1.80

    my  $jahr;           # Jahre seit 1980
    my  $tage_pro_jahr;  # 366 oder 365
    my  $n;              # Schleifenvar
    my  $d;              # Hier wird's Datum zusammengebaut
    my  $februar_29;     # Schaltjahr beruecksichtigen

    $days = 0 if ($days < 0);

    $tage_pro_jahr = 366;                # 1980 ist Schaltjahr
    $jahr = 0;
    while ($days > $tage_pro_jahr)       # Jahre feststellen
        {
        $jahr++;
        $days -= $tage_pro_jahr;
        if ($jahr % 4 == 0)              # Naechstes Jahr wieder Schaltjahr
            {
            $tage_pro_jahr = 366;
            }
        else
            {
            $tage_pro_jahr = 365;
            }
        }

    if ($jahr % 4 == 0 && $days >= 60)
        {
        $februar_29 = 1;
        $days --;
        }
    else
        {
        $februar_29 = 0;
        }

    $n = 11;                             # Nun ist days == 1..365
    while ($n > 0 && $mon[$n] >= $days)  # Finde passenden Monat
        {
        $n --;
        }
    if ($februar_29 && $days == 59)      # Dann haben wir den 29. Februar
        {
        $days ++;
        }

    $jahr += 80;
    $jahr %= 100;
    $d = sprintf "%02d.%02d.20%02d", $days - $mon[$n], $n + 1, $jahr;

    return $d;
}


# Sortierfunktionen
# =================

sub ab_num {$b <=> $a}

sub auf_num {$a <=> $b}

# ************* EOF ************************************************************

