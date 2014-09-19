#!/usr/bin/perl

use strict;
use XML::LibXML;
use File::Basename;
use Getopt::Std;

my %opts;
getopts('l:', \%opts);
my $layer = $opts{'l'};

my $CELEM1;
my $CELEM2;
my $REASON;

# NOTE: only fills with elements (no comments, etc)

my %EFILLTYPES = (XML::LibXML::XML_ELEMENT_NODE => 1,
		  XML::LibXML::XML_TEXT_NODE => 1
);

my %Layers = (raw => 1,
	      text => 1,
	      terms => 1,
	      deps => 1,
	      opinions => 1,
	      entities => 1,
	      coreferences => 1,
	      constituency => 1,
	      srl => 1,
	      timeExpressions => 1,
	      factualityLayer => 1);

&usage("Too few arguments") unless @ARGV == 2;
&usage("Bad layer name $layer") if defined $layer and not defined $Layers{$layer};

# PARSER
my $PARSER = XML::LibXML->new();
$PARSER->keep_blanks(0);

my $fname1 = $ARGV[0];
my $fname2 = $ARGV[1];

my $doc1 = $PARSER->parse_file($fname1);
my $doc2 = $PARSER->parse_file($fname2);

my $res = &cmp_node($doc1->getDocumentElement, $doc2->getDocumentElement);
print "$fname1\t$fname2\t";
if ($res) {
  print "OK\n";
} else {
  print "FAIL ($CELEM1, $CELEM2 -> $REASON)\n";
}

sub cmp_node {

  my ($node1, $node2) = @_;

  my $t1 = $node1->nodeType;
  my $t2 = $node2->nodeType;

  if ($t1 != $t2) {
    $REASON = "Node type mismatch";
    return 0;
  }

  if ($t1 == XML::LibXML::XML_ELEMENT_NODE) {
    return &cmp_elem($node1, $node2);
  }

  if ($t1 == XML::LibXML::XML_TEXT_NODE) {
    return &cmp_txt_node($node1, $node2);
  }

}

sub cmp_txt_node {
  my ($tnode1, $tnode2) = @_;

  if ($tnode1->textContent ne $tnode2->textContent) {
    $REASON = "Text content mismatch";
    return 0;
  }
  return 1;
}

# return values:
# 1 -> elem1 and elem2 are equal
# 0 -> else

sub cmp_elem {
  my ($elem1, $elem2) = @_;

  &set_nameid($elem1, \$CELEM1);
  &set_nameid($elem2, \$CELEM2);

  if ($elem1->nodeName ne $elem2->nodeName) {
    $REASON = "Element name mismatch";
    return 0;
  }
  if (not &cmp_attr($elem1, $elem2)) {
    $REASON = "Attribute mismatch";
    return 0;
  }

  my $ch1 = &fill_elem_children($elem1);
  my $ch2 = &fill_elem_children($elem2);
  my $n1 = scalar @{ $ch1 };
  my $n2 = scalar @{ $ch2 };
  if ($n1 != $n2 ) {
    $REASON = "Number of children mismatch";
    return 0;
  }
  for (my $i = 0; $i < $n1; $i++) {
    my $res = &cmp_node($ch1->[$i], $ch2->[$i]);
    return 0 unless $res;
  }
  return 1;
}

sub fill_elem_children {
  my $elem = shift;
  my $a = [];
  #foreach my $child ($elem->getChildrenByTagName("*")) {
  foreach my $child ($elem->childNodes()) {
    next unless $EFILLTYPES{$child->nodeType};
    push @{ $a }, $child;
  }
  return $a;
}

sub cmp_attr {
  my ($elem1, $elem2) = @_;

  my $atr1 = &fill_attr_hash($elem1);
  my $atr2 = &fill_attr_hash($elem2);
  return &cmp_hash($atr1, $atr2);
}

sub fill_attr_hash {
  my $elem = shift;
  my $h = {};
  foreach my $attr ($elem->attributes()) {
    next if $attr->nodeName =~ /timestamp/; # do not compare timestamps
    $h->{$attr->nodeName} = $attr->getValue();
  }
  return $h;
}

# return values:
# 1 -> h1 and h2 are  equal
# 0 -> h1 and h2 are not equal

sub cmp_hash {

  my ($h1, $h2) = @_;

  my $mm = (scalar keys %{ $h1 }) - (scalar keys %{ $h2 });
  return 0 if $mm;
  my %H = %{ $ h1 };
  while(my ($k, $v) = each %{ $h2 }) {
    return 0 unless defined $H{$k};
    return 0 unless $H{$k} eq $v;
    delete $H{$k};
  }
  return 0 if keys %H;
  return 1;
}


sub set_nameid {

  my ($elem, $celem_ptr) = @_;

  my $str;

  if ($elem->nodeType == XML::LibXML::XML_ELEMENT_NODE) {
    $str = $elem->nodeName;
  } else {
    $str = ${ $celem_ptr } ."/".$elem->nodeName;
  }

  if ($elem->getAttribute("id")) {
    $str .= "#".$elem->getAttribute("id");
  }
  ${ $celem_ptr } = $str;
}

sub usage {

  my $str = shift;
  chomp($str);
  my $bn = basename($0);
  my $msg= <<".";
  Usage: $bn [-l layer] naf1.xml naf2.xml
         -l layer : specify layer to test.
         Possible layers (raw, text, terms, deps, opinions, entities, coreferences, constituency, srl, timeExpressions, factualityLayer)
.
  print STDERR $msg;
  print STDERR "Error: $str\n" if $str;
  exit 1;
}
