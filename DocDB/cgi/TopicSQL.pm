#
#        Name: TopicSQL.pm
# Description: Routines to do DB accesses related to topics 
#              (major and minor) 
#
#      Author: Eric Vaandering (ewv@fnal.gov)
#    Modified: 
#

# Copyright 2001-2005 Eric Vaandering, Lynn Garren, Adam Bryant

#    This file is part of DocDB.

#    DocDB is free software; you can redistribute it and/or modify
#    it under the terms of version 2 of the GNU General Public License 
#    as published by the Free Software Foundation.

#    DocDB is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with DocDB; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

sub GetTopics {
  require "MeetingSQL.pm";

  my $minor_list   = $dbh->prepare("select MinorTopicID,MajorTopicID,ShortDescription,LongDescription from MinorTopic");
  my $major_list   = $dbh->prepare("select MajorTopicID,ShortDescription,LongDescription from MajorTopic");

  %MinorTopics  = ();
  %MajorTopics  = ();
  $GotAllTopics = 0;

  my ($MinorTopicID,$MajorTopicID,$ShortDescription,$LongDescription);

  $major_list -> execute;
  $major_list -> bind_columns(undef, \($MajorTopicID,$ShortDescription,$LongDescription));
  while ($major_list -> fetch) {
    $MajorTopics{$MajorTopicID}{MAJOR} = $MajorTopicID;
    $MajorTopics{$MajorTopicID}{SHORT} = $ShortDescription;
    $MajorTopics{$MajorTopicID}{LONG}  = $LongDescription;
    $MajorTopics{$MajorTopicID}{Full}  = $ShortDescription." [".$LongDescription."]";
  }

  $minor_list -> execute;
  $minor_list -> bind_columns(undef, \($MinorTopicID,$MajorTopicID,$ShortDescription,$LongDescription));
  while ($minor_list -> fetch) {
    $MinorTopics{$MinorTopicID}{MINOR} = $MinorTopicID;
    $MinorTopics{$MinorTopicID}{MAJOR} = $MajorTopicID;
    $MinorTopics{$MinorTopicID}{SHORT} = $ShortDescription;
    $MinorTopics{$MinorTopicID}{LONG}  = $LongDescription;
    $MinorTopics{$MinorTopicID}{Full}  = $MajorTopics{$MajorTopicID}{SHORT}.":".$ShortDescription;
  }
  $GotAllTopics = 1;
};

sub GetSubTopics {
  my ($MajorTopicID) = @_;
  my @MinorTopicIDs = ();
  my $MinorList = $dbh->prepare("select MinorTopicID from MinorTopic where MajorTopicID=?");

  my ($MinorTopicID);
  $MinorList -> execute($MajorTopicID);
  $MinorList -> bind_columns(undef, \($MinorTopicID));
  while ($MinorList -> fetch) {
    push @MinorTopicIDs,$MinorTopicID;
  }
  return @MinorTopicIDs;
};

sub FetchMinorTopic { # Fetches an MinorTopic by ID, adds to $Topics{$TopicID}{}
  my ($minorTopicID) = @_;
  my ($MinorTopicID,$MajorTopicID,$ShortDescription,$LongDescription);
  my $minor_fetch   = $dbh -> prepare(
    "select MinorTopicID,MajorTopicID,ShortDescription,LongDescription ".
    "from MinorTopic ".
    "where MinorTopicID=?");
  if ($MinorTopics{$minorTopicID}{MINOR}) { # We already have this one
    return $MinorTopics{$minorTopicID}{MINOR};
  }
  
  $minor_fetch -> execute($minorTopicID);
  ($MinorTopicID,$MajorTopicID,$ShortDescription,$LongDescription) = $minor_fetch -> fetchrow_array;
  &FetchMajorTopic($MajorTopicID);
  $MinorTopics{$MinorTopicID}{MINOR} = $MinorTopicID;
  $MinorTopics{$MinorTopicID}{MAJOR} = $MajorTopicID;
  $MinorTopics{$MinorTopicID}{SHORT} = $ShortDescription;
  $MinorTopics{$MinorTopicID}{LONG}  = $LongDescription;
  $MinorTopics{$MinorTopicID}{Full}  = $MajorTopics{$MajorTopicID}{SHORT}.":".$ShortDescription;

  return $MinorTopics{$MinorTopicID}{MINOR};
}

sub FetchMinorTopicByInfo (%) { # Can eventually add short/long, major topics
  my %Params = @_;
  
  my $Short = $Params{-short}; 
  
  my $Select = $dbh -> prepare("select MinorTopicID from MinorTopic where lower(ShortDescription) like lower(?)");
  $Select -> execute($Short);
  my ($MinorTopicID) = $Select -> fetchrow_array;
  
  if ($MinorTopicID) {
    &FetchMinorTopic($MinorTopicID);
  } else {
    return 0;
  }  
  return $MinorTopicID;
}

sub FetchMajorTopic { # Fetches an MajorTopic by ID, adds to $Topics{$TopicID}{}
  my ($majorTopicID) = @_;
  my ($MajorTopicID,$ShortDescription,$LongDescription);
  my $major_fetch   = $dbh -> prepare(
    "select MajorTopicID,ShortDescription,LongDescription ".
    "from MajorTopic ".
    "where MajorTopicID=?");
  if ($MajorTopics{$majorTopicID}{MAJOR}) { # We already have this one
    return $MajorTopics{$majorTopicID}{MAJOR};
  }

  $major_fetch -> execute($majorTopicID);
  ($MajorTopicID,$ShortDescription,$LongDescription) = $major_fetch -> fetchrow_array;
  $MajorTopics{$MajorTopicID}{MAJOR} = $MajorTopicID;
  $MajorTopics{$MajorTopicID}{SHORT} = $ShortDescription;
  $MajorTopics{$MajorTopicID}{LONG}  = $LongDescription;

  return $MajorTopics{$MajorTopicID}{MAJOR};
}

sub GetRevisionTopics {
  my ($DocRevID) = @_;
  
  require "Utilities.pm";
  
  my @topics = ();
  my ($RevTopicID,$MinorTopicID);
  my $topic_list = $dbh->prepare(
    "select RevTopicID,MinorTopicID from RevisionTopic where DocRevID=?");
  $topic_list -> execute($DocRevID);
  $topic_list -> bind_columns(undef, \($RevTopicID,$MinorTopicID));
  while ($topic_list -> fetch) {
    if (&FetchMinorTopic($MinorTopicID)) {
      push @topics,$MinorTopicID;
    }  
  }
  @topics = &Unique(@topics);
  return @topics;
}

sub GetTopicDocuments {
  my ($TopicID) = @_;
  
  require "RevisionSQL.pm";

  my $DocumentID;
  my $DocRevID;
  my %DocumentIDs;

  my $RevisionList = $dbh -> prepare("select DocRevID from RevisionTopic where MinorTopicID=?"); 
  my $DocumentList = $dbh -> prepare("select DocumentID from DocumentRevision where DocRevID=? and Obsolete=0"); 
  $RevisionList -> execute($TopicID);
  $RevisionList -> bind_columns(undef, \($DocRevID));

  while ($RevisionList -> fetch) {
    &FetchDocRevisionByID($DocRevID);
    if ($DocRevisions{$DocRevID}{Obsolete}) {next;}
    $DocumentList -> execute($DocRevID);
    ($DocumentID) = $DocumentList -> fetchrow_array;
    $DocumentIDs{$DocumentID} = 1; # Hash removes duplicates
  }
  my @DocumentIDs = keys %DocumentIDs;
  return @DocumentIDs;
}

sub LookupMajorTopic { # Returns MajorTopicID from Topic Name
  my ($TopicName) = @_;
  my $major_fetch   = $dbh -> prepare(
    "select MajorTopicID from MajorTopic where ShortDescription=?");

  $major_fetch -> execute($TopicName);
  my $MajorTopicID = $major_fetch -> fetchrow_array;
  &FetchMajorTopic($MajorTopicID);
  
  return $MajorTopicID;
}

sub MatchMajorTopic ($) { # FIXME: Make LookupMajorTopic a subset?
  my ($ArgRef) = @_;
  my $Short = exists $ArgRef->{-short} ? $ArgRef->{-short} : "";
#  my $Long  = exists $ArgRef->{-long}   ? $ArgRef->{-long}   : "";
  my $MajorID;
  my @MatchIDs = ();
  if ($Short) {
    $Short =~ tr/[A-Z]/[a-z]/;
    $Short = "%".$Short."%";
    my $List = $dbh -> prepare(
       "select MajorTopicID from MajorTopic where LOWER(ShortDescription) like ?"); 
    $List -> execute($Short);
    $List -> bind_columns(undef, \($MajorID));
    while ($List -> fetch) {
      push @MatchIDs,$MajorID;
    }
  }
  return @MatchIDs;
}

sub MatchMinorTopic ($) {
  my ($ArgRef) = @_;
  my $Short = exists $ArgRef->{-short} ? $ArgRef->{-short} : "";
#  my $Long  = exists $ArgRef->{-long}   ? $ArgRef->{-long}   : "";
  my $MinorID;
  my @MatchIDs = ();
  if ($Short) {
    $Short =~ tr/[A-Z]/[a-z]/;
    $Short = "%".$Short."%";
    my $List = $dbh -> prepare(
       "select MinorTopicID from MinorTopic where LOWER(ShortDescription) like ?"); 
    $List -> execute($Short);
    $List -> bind_columns(undef, \($MinorID));
    while ($List -> fetch) {
      push @MatchIDs,$MinorID;
    }
  }
  return @MatchIDs;
}

sub InsertTopics (%) {
  my %Params = @_;
  
  my $DocRevID =   $Params{-docrevid} || "";   
  my @TopicIDs = @{$Params{-topicids}};

  my $Count = 0;

  my $Insert = $dbh -> prepare("insert into RevisionTopic (RevTopicID, DocRevID, MinorTopicID) values (0,?,?)");
                                 
  foreach my $TopicID (@TopicIDs) {
    if ($TopicID) {
      $Insert -> execute($DocRevID,$TopicID);
      ++$Count;
    }
  }  
      
  return $Count;
}

1;
