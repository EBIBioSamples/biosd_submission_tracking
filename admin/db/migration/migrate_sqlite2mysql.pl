#!/usr/bin/env perl
#
# Very basic script to take the SQLite dump from the old autosubs
# database and convert it into something MySQL can load. The MySQL
# output assumes that the tables have already been created using the
# SQL in the automation/admin/db directory. This is a one-off job,
# provided here as a convenience.
#
# $Id$

use strict;
use warnings;

my $sqlite_file = shift;

unless ($sqlite_file) {
    die ("Usage: $0 sqlite_sql_dump_file.txt > mysql_sql.txt\n");
}

open(my $sqlite, '<', $sqlite_file) or die($!);

# Split on SQL statements, each terminated with a semicolon. Note that
# we're assuming Unix line-endings here.
local $/ = ";\n";

my $create_table = qr/\A [ ]* CREATE [ ]+ TABLE [ ]+ `?(\w+)`?/xms;
my $insert_into  = qr/\A [ ]* INSERT [ ]+ INTO/xms;

my %schema;
CHUNK:
while ( my $chunk = <$sqlite> ) {

    next CHUNK if ( $chunk =~ /sqlite_sequence/i );

    if ( my ($table) = ($chunk =~ /$create_table/i) ) {
	$chunk =~ s/$create_table [ ]+ \(\n//xms;
	$chunk =~ s/\);\n \z//xms;
	chomp $chunk;
	my @cols = map { ($_ =~ /\A [ ]* (\w+)/xms) } split /,[\n ]*/, $chunk;
	$schema{$table} = \@cols;
    }

    if ( $chunk =~ /$insert_into/i ) {
	$chunk =~ s/"/`/g;
	if ( my ($table) = ($chunk =~ /$insert_into [ ]+ `([^`]+)`/ixms) ) {

	    unless ( $schema{$table} ) {
		die(qq{Error: Table "$table" has undefined schema.\n});
	    }

	    my $columnlist = q{(} . join(',', map {"`$_`"} @{ $schema{$table} }) . q{)};

	    $chunk =~ s/($insert_into [ ]+ `?${table}`?) [ ]+ VALUES/$1 $columnlist VALUES/ixms
		or die("Error: can't substitute into chunk:\n\n$chunk\n");

	    print $chunk;
	}
	else {
	    die("Error: can't detect table name in chunk:\n\n$chunk\n");
	}
    }
}

close($sqlite);
