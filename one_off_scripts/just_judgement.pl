use Concordance::Judgement;
use Concordance::Utils;

if (@ARGV == 0) { die "just_judgement.pl <run_ids_file> <project_name> <output_csv> <results_email> <birdseed_txt_dir>\n" }

my %samples = Concordance::Utils->populate_sample_info_hash(
    Concordance::Utils->load_runIds_from_file($ARGV[0]));

my $judgement = Concordance::Judgement->new;
$judgement->project_name($ARGV[1]);
$judgement->output_csv($ARGV[2]);
$judgement->samples(\%samples);
$judgement->birdseed_txt_dir($ARGV[4]);
(my $email_list = $ARGV[3]) =~ s/@/\\@/g;
$judgement->results_email_address($email_list);
$judgement->execute;

