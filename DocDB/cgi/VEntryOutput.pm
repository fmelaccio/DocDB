#
#        Name: VEntryOutput.pm
# Description: Routines to produce iCal formatted lists of events
#
#    Revision: $Revision$
#    Modified: $Author$ on $Date$
#
#      Author: Eric Vaandering (ewv@fnal.gov)

# Copyright 2001-2009 Eric Vaandering, Lynn Garren, Adam Bryant

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
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

use Data::ICal;
use Data::ICal::Entry::Event;
use DateTime::Format::ICal;

require "SQLUtilities.pm";
require "EventUtilities.pm";
require "MeetingSQL.pm";
require "MeetingHTML.pm";

sub NewICal {
  my $Calendar = Data::ICal->new();
  return $Calendar;
}

sub ICalHeader {
  my $Header;
  $Header .= "Content-Type: text/calendar\n";
  $Header .= "\n";
  return $Header;
}

sub ICalEventEntry {

}

sub ICalSessionEntry {
  my ($ArgRef) = @_;

  my $SessionID = exists $ArgRef->{-sessionid} ? $ArgRef->{-sessionid} : 0;
  my $Event = Data::ICal::Entry::Event->new();
  unless ($SessionID) {return $Event}
  FetchSessionByID($SessionID);

  # Map names of DocDB Session fields into iCal format fields
  my %ICalMapping = (Title => summary, Description => description, Location => location,);

  my %SessionHash = ();

  $SessionHash{url} = "$DisplayMeeting?sessionid=$SessionID";

  my $Moderators = "";
  my @ModeratorIDs = @{$Conferences{$EventID}{Moderators}};
  foreach my $ModeratorID (@ModeratorIDs) {
    FetchAuthor($ModeratorID);
    $Moderators .= $Authors{$AuthorID}{FULLNAME};
  }
  $SessionHash{"x-moderators"} = $Moderators;

  # Start & End Time
  SessionEndTime($SessionID);
  my $ICalFormatter = DateTime::Format::ICal->new();

  $SessionHash{dtstart} = $ICalFormatter->format_datetime($Sessions{$SessionID}{StartDateTime});
  $SessionHash{dtend}   = $ICalFormatter->format_datetime($Sessions{$SessionID}{EndDateTime});

  foreach my $Key (keys %ICalMapping) {
    if ($Sessions{$SessionID}{$Key}) {
      $SessionHash{$ICalMapping{$Key}} = $Sessions{$SessionID}{$Key};
    }
  }

  $Event->add_properties(%SessionHash);
  return $Event;
}

1;
