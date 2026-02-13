#!/usr/bin/perl
###############################################################################
# Nom del Plugin : check_eks_remote.v2.7.pl
# Autor          : Pep Rojo (UIS - UPF)
# Versió         : 2.7
# Data           : 2026-02-13
#
# DESCRIPCIÓ:
# ---------------------------------------------------------------------------
# Plugin de monitorització per clústers AWS EKS executat des de Nagios.
#
# MODEL DE SEGURETAT:
# nagios → ec2-user → sudo -u admin-eks → script remot
#
# COMANDES:
#   Reiniciats → Pods amb restartCount incrementat
#   Stat       → Pods en estat incorrecte
#   Volcat     → Diferències en recursos (CPU/memòria)
#
# OPCIONS:
#   -c <cmd>    Reiniciats | Stat | Volcat
#   -d          Debug
#   --debug     Debug
#   --selftest  Test SSH + sudo + path remot
#   --help      Mostra ajuda
#
# CANVIS v2.7 (corregit):
# ---------------------------------------------------------------------------
# - Stat: lògica robusta "si hi ha sortida → WARNING" (heretada de v2.3/v2.4)
#   amb parser dual (format anglès i català) per generar resum,
#   però MAI retornar OK si hi ha sortida (fail-closed).
# - run_remote: backticks correctes per executar realment la comanda SSH.
# - selftest: backticks correctes per a les comprovacions SSH.
# - debug Reiniciats: sudo -n -u consistent amb run_remote.
# - Volcat: RC=1 tractat com "drift detectat" (no error d'execució).
# - Volcat parser: normalització i extracció de deploys amb diff.
###############################################################################

use strict;
use warnings;
use Getopt::Long;

# ---------------- CONFIG ----------------
my $SSH_KEY     = "/etc/nagios/ssh-keys/KP-gestor-eks-pre.pem";
my $SSH_USER    = "ec2-user";
my $SSH_HOST    = "10.53.1.132";
my $REMOTE_USER = "admin-eks";
my $REMOTE_PATH = "/sx/scripts/scc";

# Volcat tuning
my $VOLCAT_MAX_SHOW        = 4;   # quants deploys mostrem al summary
my $VOLCAT_MAX_DETAILLINES = 12;  # quantes línies de diff deixem al debug/extra

my $command;
my $debug    = 0;
my $selftest = 0;
my $help     = 0;

GetOptions(
    "c=s"      => \$command,
    "d"        => \$debug,
    "debug"    => \$debug,
    "selftest" => \$selftest,
    "help"     => \$help,
);

# ---------------- HELP ----------------
if ($help) {
    print << "EOF";
check_eks_remote.v2.7.pl

ÚS:
  -c Reiniciats
  -c Stat
  -c Volcat

OPCIONS:
  -d, --debug   Mostra execució SSH i, en Reiniciats, inclou describe + logs
                dels pods afectats.
  --selftest    Verifica:
                - Existència clau SSH
                - Connexió SSH
                - Sudo a admin-eks
                - Existència directori remot
  --help        Mostra aquesta ajuda

SORTIDA:
  OK / WARNING / CRITICAL / UNKNOWN
  Format compatible amb Nagios

EXEMPLES:
  ./check_eks_remote.v2.7.pl -c Reiniciats
  ./check_eks_remote.v2.7.pl -c Reiniciats -d
  ./check_eks_remote.v2.7.pl -c Volcat
  ./check_eks_remote.v2.7.pl --selftest
EOF
    exit 0;
}

# ---------------- UTILS ----------------
sub debug_log {
    my ($msg) = @_;
    return unless $debug;
    my $ts = localtime();
    print "[DEBUG][$ts] $msg\n";
}

sub exit_ok       { print "OK: $_[0]\n";       exit 0; }
sub exit_warning  { print "WARNING: $_[0]\n";  exit 1; }
sub exit_critical { print "CRITICAL: $_[0]\n"; exit 2; }
sub exit_unknown  { print "UNKNOWN: $_[0]\n";  exit 3; }

# ---------------- EXEC REMOTA ----------------
sub run_remote {
    my ($cmd) = @_;

    # pipefail + echo RC per capturar bé l'RC del remot
    my $remote = "set -o pipefail; sudo -n -u $REMOTE_USER $REMOTE_PATH/$cmd; echo \"__RC=\$?__\"";

    my $full = "ssh -o BatchMode=yes -o ConnectTimeout=15 -i $SSH_KEY "
             . "$SSH_USER\@$SSH_HOST "
             . "'$remote' 2>&1";

    debug_log("Exec: $cmd");
    debug_log("SSH: $full") if $debug;

    my $out = `$full`;
    my $rc  = 3;

    if ($out =~ /__RC=(\d+)__/s) {
        $rc = $1;
        $out =~ s/__RC=\d+__\s*//s;   # neteja marcador
    } else {
        # si no trobem RC, fem fallback
        $rc = $? >> 8;
    }

    debug_log("RC=$rc");
    return ($rc, $out);
}

# ---------------- VOLCAT PARSER ----------------
sub parse_volcat_diff {
    my ($out) = @_;

    my $norm = $out;
    $norm =~ s/\r//g;

    # Si el diff arriba en una sola línia, el normalitzem.
    # Converteix " < name ..." i " > name ..." en línies.
    $norm =~ s/\s+([<>])\s+/\n$1 /g;
    $norm =~ s/\s*---\s*/\n---\n/g;

    my %seen;
    for my $line (split(/\n/, $norm)) {
        # línies: "< gelapi-deploy {...}" o "> sample-deploy {...}"
        if ($line =~ /^[<>]\s+(\S+)/) {
            $seen{$1} = 1;
        }
    }

    my @deploys = sort keys %seen;
    my $count   = scalar @deploys;

    my @show = @deploys;
    if (@show > $VOLCAT_MAX_SHOW) {
        @show = @show[0 .. $VOLCAT_MAX_SHOW - 1];
    }

    my $rest     = $count - scalar(@show);
    my $show_str = join(", ", @show);
    $show_str .= " (+$rest més)" if $rest > 0;

    # Detall: primeres N línies no buides, ja normalitzades
    my @lines = grep { $_ =~ /\S/ } split(/\n/, $norm);
    if (@lines > $VOLCAT_MAX_DETAILLINES) {
        @lines = @lines[0 .. $VOLCAT_MAX_DETAILLINES - 1];
    }
    my $detail = join("\n", @lines);

    return ($count, $show_str, $detail);
}

# ---------------- SELFTEST ----------------
if ($selftest) {
    exit_critical("Clau SSH no existeix: $SSH_KEY") unless -f $SSH_KEY;

    my $ssh = `ssh -o BatchMode=yes -o ConnectTimeout=10 -i $SSH_KEY $SSH_USER\@$SSH_HOST "echo OK" 2>&1`;
    my $rc  = $? >> 8;
    exit_critical("SSH fallida: $ssh") if $rc != 0;

    my $sudo = `ssh -o BatchMode=yes -o ConnectTimeout=10 -i $SSH_KEY $SSH_USER\@$SSH_HOST "sudo -n -u $REMOTE_USER whoami" 2>&1`;
    $rc = $? >> 8;
    exit_critical("Sudo fallit: $sudo") if $rc != 0;
    exit_critical("Usuari incorrecte (esperat $REMOTE_USER): $sudo")
        unless $sudo =~ /\b$REMOTE_USER\b/;

    my $path = `ssh -o BatchMode=yes -o ConnectTimeout=10 -i $SSH_KEY $SSH_USER\@$SSH_HOST "test -d $REMOTE_PATH && echo OK" 2>&1`;
    $rc = $? >> 8;
    exit_critical("Directori scripts no existeix: $REMOTE_PATH") if $rc != 0;

    exit_ok("Selftest correcte");
}

exit_unknown("Comanda no especificada (-c)") unless $command;

# ---------------- INFRA NAMESPACES ----------------
my %infra_ns = map { $_ => 1 } (
    "amazon-cloudwatch",
    "amazon-network-flow-monitor",
    "commvault",
    "default",
    "ingress-nginx",
    "kube-node-lease",
    "kube-public",
    "kube-system",
    "sso-pre",
    "uis-pre",
    "upf-pre",
    "velero"
);

# ============================================================================
# REINICIATS
# ============================================================================
if ($command =~ /^Reiniciats$/i) {

    my ($rc, $out) = run_remote("pod-restarted");
    exit_critical("Error execució remota (pod-restarted): $out") if $rc != 0;

    my @pods;
    while ($out =~ /pod\s+(\S+).*namespace\s+(\S+).*ha reiniciat\s+(\d+).*?\((.*?)\s+ago\)/g) {
        my ($pod, $ns, $count, $ago) = ($1, $2, $3, $4);
        my $minutes = 999999;
        if    ($ago =~ /(\d+)m/) { $minutes = $1; }
        elsif ($ago =~ /(\d+)h/) { $minutes = $1 * 60; }
        elsif ($ago =~ /(\d+)d/) { $minutes = $1 * 1440; }
        push @pods, { pod => $pod, ns => $ns, count => $count, minutes => $minutes };
    }

    my $total = scalar @pods;
    exit_ok("Sense pods reiniciats") if $total == 0;

    @pods = sort { $a->{minutes} <=> $b->{minutes} } @pods;
    my @preview = @pods[0 .. ($#pods < 3 ? $#pods : 3)];

    my @infra = grep {  $infra_ns{ $_->{ns} } } @pods;
    my @apps  = grep { !$infra_ns{ $_->{ns} } } @pods;

    my $infra_total = scalar @infra;
    my $app_total   = scalar @apps;

    my @msg = map { "$_->{ns}/$_->{pod}($_->{count})" } @preview;
    my $summary = "$total pods reiniciats | infra:$infra_total app:$app_total | Últims: "
                . join(", ", @msg);

    print "CRITICAL: $summary | pods_reiniciats=$total;;;;\n";

    if ($debug) {
        for my $p (@preview) {
            print "\n[DEBUG] Describe $p->{ns}/$p->{pod}\n";
            my $desc = `ssh -o BatchMode=yes -o ConnectTimeout=15 -i $SSH_KEY $SSH_USER\@$SSH_HOST "sudo -n -u $REMOTE_USER kubectl describe pod $p->{pod} -n $p->{ns} | tail -n 10" 2>&1`;
            print "$desc\n";
            print "[DEBUG] Logs $p->{ns}/$p->{pod}\n";
            my $logs = `ssh -o BatchMode=yes -o ConnectTimeout=15 -i $SSH_KEY $SSH_USER\@$SSH_HOST "sudo -n -u $REMOTE_USER kubectl logs $p->{pod} -n $p->{ns} --tail=20" 2>&1`;
            print "$logs\n";
        }
    }
    exit 2;
}

# ============================================================================
# STAT  (FIX: lògica robusta fail-closed, mai OK si hi ha sortida)
# ============================================================================
if ($command =~ /^Stat$/i) {

    my ($rc, $out) = run_remote("stat-pods");
    exit_critical("Error execució remota (stat-pods): $out") if $rc != 0;

    # -----------------------------------------------------------------------
    # Regla d'or: si NO hi ha sortida → tot correcte.
    # -----------------------------------------------------------------------
    if ($out !~ /\S/) {
        exit_ok("Tots els pods correctes");
    }

    # -----------------------------------------------------------------------
    # Hi ha sortida → alguna cosa va malament.  Intentem parsejar en 2 formats
    # per generar un resum, però SEMPRE retornarem CRITICAL com a mínim.
    # -----------------------------------------------------------------------
    my @bad;

    # Format 1: "pod X ... namespace Y ... estat Z"
    while ($out =~ /pod\s+(\S+).*?namespace\s+(\S+).*?estat\s+(\S+)/g) {
        push @bad, "$2/$1($3)";
    }

    # Format 2: "Estat del pod X del namespace Y és Z"
    while ($out =~ /Estat\s+del\s+pod\s+(\S+).*?del\s+namespace\s+(\S+).*?\s(?:és|es)\s+(\S+)/gi) {
        my ($pod, $ns, $state) = ($1, $2, $3);
        push @bad, "$ns/$pod($state)";
    }

    # Dedup
    my %seen;
    @bad = grep { !$seen{$_}++ } @bad;

    my $total = scalar(@bad);

    # Si NO hem pogut parsejar cap pod, igualment CRITICAL amb el text cru
    # (cap fals OK — fail-closed)
    if ($total == 0) {
        print "CRITICAL: Pods amb estat incorrecte (format inesperat). "
            . "Mostra parcial: " . substr($out, 0, 220)
            . " | pods_bad=1;;;;\n";
        exit 2;
    }

    my @preview = @bad[0 .. ($#bad < 3 ? $#bad : 3)];

    print "CRITICAL: $total pods amb estat incorrecte | Últims: "
        . join(", ", @preview)
        . " | pods_bad=$total;;;;\n";
    exit 2;
}

# ============================================================================
# VOLCAT
# ============================================================================
if ($command =~ /^Volcat$/i) {

    my ($rc, $out) = run_remote("volcat-deploy-get-resources-scc");

    # RC=1 és "drift detectat" -> NO és error d'execució
    if ($rc != 0 && $rc != 1) {
        exit_critical("Error execució remota (volcat): RC=$rc | $out");
    }

    # Si no hi ha sortida, no hi ha drift.
    if ($out !~ /\S/) {
        exit_ok("Cap diferència detectada | drift=0;;;;");
    }

    my ($count, $show_str, $detail) = parse_volcat_diff($out);

    # Si hi ha diff però no hem pogut parsejar deploys, ho diem clar
    if ($count == 0) {
        print "WARNING: Volcat drift detectat però parser sense matches "
            . "(format inesperat) | drift=0;;;;\n";
        print "$out\n" if $debug;
        exit 1;
    }

    print "WARNING: Volcat drift: $count deploy(s) difereixen: "
        . "$show_str | drift=$count;;;;\n";
    if ($debug) {
        print "\n[DEBUG] Diff (normalitzat, primeres $VOLCAT_MAX_DETAILLINES línies):\n";
        print "$detail\n";
    }
    exit 1;
}

exit_unknown("Comanda no reconeguda");
