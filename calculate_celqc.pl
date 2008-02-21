#!/usr/bin/env perl
#
# Script to automate CEL QC checks run across the whole AE database,
# processed in parallel using the LSF batch job submission system.
#
# $Id$

use strict;
use warnings;

# NOTE: no "use lib" placeholder for this script, because it uses a
# PATH specific to the LSF cluster which is maintained in the shell
# wrapper for this script.

use ArrayExpress::Tracking::QCJobManager;
use ArrayExpress::Curator::Database qw(get_ae_dbh);

# Create AE statement handle, start JobManager.
my $dbh = get_ae_dbh();

my $sth = $dbh->prepare(<<'QUERY', { ora_auto_lob => 0 });
select di.identifier as identifier,
 di.id as dbid,
 bdc.dataformat as dataformat,
 bdc.netcdf as lob
from tt_identifiable i,
 tt_experiment e,
 tt_bioassaydata_t_experimen de,
 tt_bioassaydata d,
 tt_identifiable di,
 tt_biodatacube bdc,
 pl_label l
where i.id=e.id
and i.id=l.mainobj_id
and e.id=de.t_experiment_id
and de.bioassaydata_id=d.id
and d.id=di.id
and d.biodatavalues_id=bdc.id
and bdc.dataformat in ('CELv3','CELv4')
and i.identifier!='E-TABM-185'
QUERY

$sth->execute() or die($sth->errstr());

# num_procs is the maximum number of concurrent processes.
my $manager = ArrayExpress::Tracking::QCJobManager->new({
    ae_sth      => $sth,
    ae_dbh      => $dbh,
    num_procs   => 20,
});

$manager->run();
