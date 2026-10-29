package CXGN::Trial::ParseUpload::Plugin::TrialEntryNumbers;

use utf8;
use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Trial::TrialLookup;
use CXGN::Stock::StockLookup;

sub _validate_with_plugin {
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();

  my %errors;
  my @error_messages;
  my %warnings;
  my @warning_messages;

  # Match a dot, extension .xls / .xlsx
  my ($extension) = $filename =~ /(\.[^.]+)$/;
  my $parser;

  if ($extension eq '.xlsx') {
    $parser = Spreadsheet::ParseXLSX->new();
  }
  else {
    $parser = Spreadsheet::ParseExcel->new();
  }

  my $excel_obj;
  my $worksheet;
  my %seen_accession_names;
  my %seen_trial_names;
  my %seen_entry_numbers;
  my %parsed_data;


  #try to open the excel file and report any errors
  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    push @error_messages, $parser->error();
    $errors{'error_messages'} = \@error_messages;
    $self->_set_parse_errors(\%errors);
    return;
  }

  $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
  if (!$worksheet) {
      push @error_messages, "A planilha deve estar na 1ª aba do arquivo Excel (.xls)";
      $errors{'error_messages'} = \@error_messages;
      $self->_set_parse_errors(\%errors);
      return;
  }
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();
  if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
    push @error_messages, "A planilha não tem cabeçalho ou não contém linhas";
    $errors{'error_messages'} = \@error_messages;
    $self->_set_parse_errors(\%errors);
    return;
  }

  #get column headers
  my $accession_name_head;
  my $trial_names_head;
  my $entry_number_head;

  if ($worksheet->get_cell(0,0)) {
    $accession_name_head  = $worksheet->get_cell(0,0)->value();
    $accession_name_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,1)) {
    $trial_names_head  = $worksheet->get_cell(0,1)->value();
    $trial_names_head =~ s/^\s+|\s+$//g;
  }
  if ($worksheet->get_cell(0,2)) {
    $entry_number_head  = $worksheet->get_cell(0,2)->value();
    $entry_number_head =~ s/^\s+|\s+$//g;
  }

  if (!$accession_name_head || $accession_name_head ne 'accession_name' ) {
    push @error_messages, "Célula A1: accession_name está ausente do cabeçalho";
  }
  if (!$trial_names_head || $trial_names_head ne 'trial_names' ) {
    push @error_messages, "Célula A1: trial_names está ausente do cabeçalho";
  }
  if (!$entry_number_head || $entry_number_head ne 'entry_number' ) {
    push @error_messages, "Célula A1: entry_number está ausente do cabeçalho";
  }

  for my $row ( 1 .. $row_max ) {
    my $row_name = $row+1;
    my $accession_name;
    my $trial_names_str;
    my $entry_number;

    if ($worksheet->get_cell($row,0)) {
      $accession_name = $worksheet->get_cell($row,0)->value();
    }
    if ($worksheet->get_cell($row,1)) {
      $trial_names_str = $worksheet->get_cell($row,1)->value();
    }
    if ($worksheet->get_cell($row,2)) {
      $entry_number =  $worksheet->get_cell($row,2)->value();
    }

    #skip blank lines
    if ( (!$accession_name && !$trial_names_str && !$entry_number) || !$entry_number ) {
      next;
    }

    #check required fields and track values
    if (!$accession_name || $accession_name eq '' ) {
      push @error_messages, "Célula A$row_name: accession_name ausente.";
    }
    else {
      $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
      $seen_accession_names{$accession_name}++;
    }

    if (!$trial_names_str || $trial_names_str eq '' ) {
      push @error_messages, "Célula B$row_name: trial_names ausente.";
    }
    else {
      my @trial_names = split(',', $trial_names_str);
      foreach my $trial_name (@trial_names) {
        $trial_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_trial_names{$trial_name} = 1;

        ##
        ## SET PARSED DATA
        ##
        $parsed_data{$trial_name}{$accession_name} = $entry_number;
      }
    }

    if ($entry_number && $entry_number ne '' ) {
      $seen_entry_numbers{$entry_number}++;
    }
  }

  # Check Accessions:
  # - name exists as stock entry
  # - accession name used only once per file
  my @accession_names = keys %seen_accession_names;
  my $accession_name_validator = CXGN::List::Validate->new();
  my @accession_names_missing = @{$accession_name_validator->validate($schema, 'accessions', \@accession_names)->{'missing'}};
  if ( scalar(@accession_names_missing) > 0 ) {
    $errors{'missing_accessions'} = \@accession_names_missing;
    push(@error_messages, "Os seguintes nomes de acessos não estão no banco de dados como nomes únicos ou sinônimos: " . join(',', @accession_names_missing));
  }
  foreach my $accession_name (@accession_names) {
    if ( $seen_accession_names{$accession_name} > 1 ) {
      push(@warning_messages, "O acesso $accession_name foi usado mais de uma vez no arquivo");
    }
  }

  # Check Trials:
  # - name exists as project entry
  my @trial_names = keys %seen_trial_names;
  my $trial_name_validator = CXGN::List::Validate->new();
  my @trial_names_missing = @{$trial_name_validator->validate($schema, 'trials', \@trial_names)->{'missing'}};
  if ( scalar(@trial_names_missing) > 0 ) {
    $errors{'missing_trials'} = \@trial_names_missing;
    push(@error_messages, "Os seguintes nomes de ensaios não estão no banco de dados: " . join(',', @trial_names_missing));
  }

  # Check Entry Numbers:
  # - each number used only once
  my @entry_numbers = keys %seen_entry_numbers;
  foreach my $entry_number (@entry_numbers) {
    if ( $seen_entry_numbers{$entry_number} > 1 ) {
      push(@error_messages, "O número de entrada $entry_number é usado mais de uma vez no arquivo");
    }
  }

  #store any warnings found in the parsed file
  if ( scalar(@warning_messages) >= 1)  {
      $warnings{'warning_messages'} = \@warning_messages;
      $self->_set_parse_warnings(\%warnings);
  }

  #store any errors found in the parsed file, and return
  if ( scalar(@error_messages) >= 1 ) {
      $errors{'error_messages'} = \@error_messages;
      $self->_set_parse_errors(\%errors);
      return;
  }

  # Temporarily set partially parsed data, to be used in the parse function
  $self->_set_parsed_data(\%parsed_data);
  return 1;

}


sub _parse_with_plugin {
  my $self = shift;
  my $schema = $self->get_chado_schema();

  # Parse Trial and Stock Names to IDs
  my $validated_data = $self->_parsed_data();
  my %parsed_data;
  foreach my $trial_name (keys %$validated_data) {
    my $trial_lookup = CXGN::Trial::TrialLookup->new({ schema => $schema, trial_name => $trial_name });
    my $trial_id = $trial_lookup->get_trial()->project_id();
    foreach my $stock_name (keys %{$validated_data->{$trial_name}}) {
      my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema, stock_name => $stock_name });
      my $stock_id = $stock_lookup->get_stock_exact()->stock_id();
      $parsed_data{$trial_id}{$stock_id} = $validated_data->{$trial_name}->{$stock_name};
    }
  }
  $self->_set_parsed_data(\%parsed_data);

  return 1;
}


1;
