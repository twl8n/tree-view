#!/usr/bin/env perl
use strict;

my %tree;                       # the analysis tree as read in from the db
my %parent;                     # key is node, value is node's parent
my %children;                   # key is node, value is a list of children nodes
my %node2g;                     # key is node, value is a generation
my @generation;                 # key is generation, value is a list of nodes in this generation
my %loc;                        # key is node, value is a list of row,col
my @table;                      # 2D array, indices are [row][col], values are nodes
my @colors;                     # 2D array, indices are [row][col], values are HTML colors
my @m_width;                    # 1D array, index is node, value is max width of all subsequent generations 


my $GEOSS_DIR = '';
my $VERSION = 1;
my $WEB_DIR = '';

my @data = ({tree_name => "foo",
             node_pk => 1,
             an_name => "",
             parent_key => -1,
             an_fk => -1,
             version => 1,
             an_type => "ant"},
            {tree_name => "foo",
             node_pk => 2,
             an_name => "",
             parent_key => 1,
             an_fk => -1,
             version => 2,
             an_type => "ant"},
            {tree_name => "foo",
             node_pk => 3,
             an_name => "",
             parent_key => 1,
             an_fk => -1,
             version => 3,
             an_type => "ant"},
            {tree_name => "foo",
             node_pk => 4,
             an_name => "",
             parent_key => 2,
             an_fk => -1,
             version => 4,
             an_type => "ant"},
            {tree_name => "foo",
             node_pk => 5,
             an_name => "",
             parent_key => 3,
             an_fk => -1,
             version => 5,
             an_type => "ant"},
            {tree_name => "foo",
             node_pk => 6,
             an_name => "",
             parent_key => 3,
             an_fk => -1,
             version => 6,
             an_type => "ant"},
            {tree_name => "foo",
             node_pk => 7,
             an_name => "",
             parent_key => 3,
             an_fk => -1,
             version => 7,
             an_type => "ant"},
           {tree_name => "foo",
             node_pk => 8,
             an_name => "",
             parent_key => 3,
             an_fk => -1,
             version => 8,
             an_type => "ant"});

sub read_db
{
    my $tree_pk = 1;            # Warning! hard coded duplicate
    # while(( my $tree_name, my $node_pk, my $an_name, my $parent_key, my $an_fk,
    #         my $version, my $an_type) = $sth->fetchrow_array())
    while (my $dref = shift(@data))
    {
        my $tree_name = $dref->{tree_name};
        my $node_pk = $dref->{node_pk};
        my $an_name = "$dref->{tree_name} $dref->{node_pk}" ; # $dref->{an_name};
        my $parent_key = $dref->{parent_key};
        my $an_fk = $dref->{an_fk};
        my $version = $dref->{version};
        my $an_type = $dref->{an_type};
        push(@{$tree{$node_pk}}, "${an_name}<br><br>Version: $version"); # [0]
        push(@{$tree{$node_pk}}, $parent_key);                           # [1]
        push(@{$tree{$node_pk}}, $an_fk);                                # [2]
        push(@{$tree{$node_pk}}, $tree_pk);                              # [3]
        push(@{$tree{$node_pk}}, "${an_type}_$version");                 # [4]
       
        if ($parent_key == -1)
        {
            $tree{root} = $node_pk;
            $tree{tree_name} = $tree_name;
            $parent{$node_pk} = -1; # we can only have one parent
            $node2g{$node_pk} = 0;  # my generation zero
            # add self to my generation's list
            push(@{$generation[$node2g{$node_pk}]}, $node_pk); 
        }
        else
        {
            $parent{$node_pk} = $parent_key;
            push(@{$children{$parent_key}}, $node_pk);
            # nodes must be processed in order
            $node2g{$node_pk} = $node2g{$parent{$node_pk}} + 1; 
            push(@{$generation[$node2g{$node_pk}]}, $node_pk); # ditto
        }
    }

    #  $tree{properties_node_pk} = $ch{properties_node_pk};
    $tree{tree_pk} = $tree_pk;

    # I know... %tree is a package global, and we're returning it.
    return %tree;
}

#
# find max width for each family.
# $m_width[$xx] = max; where $node is the index into @tree.
#
sub pass1
{
    my $row;
    my $col;
    my %zero_children;

    $row = 0;
    $col = 0;
    for (my $xx=$#generation; $xx>=0; $xx--)
    {
        my $yy;
        for ($yy = 0; $yy<=$#{$generation[$xx]}; $yy++)
        {
            my $node = $generation[$xx][$yy];
            $m_width[$node] = 0;
            my $cc;
            for ($cc=0; $cc<=$#{$children{$node}}; $cc++)
            {
                my $chw = ($m_width[$children{$node}[$cc]]);
                $m_width[$node] += $chw;
            }
            if ($m_width[$node] < 1)
            {
                $m_width[$node] = 1; 
            }
        }
    }
}

# Place parent at 1/2 of the child's generation width
# Need a pass to group children of a generation by family.
# If a node has no children, then it doesn't count in the spacing of 
# the next generation, and its col is just col+1.
# If a node has children, then place the node in the middle of the subsequent generation,
# 
sub pass2
{
    my $row;
    my $col;

    $row = 0;
    $col = 0;
    my $node;
    my $parent;
    # Layout children of generation $xx, and special case the root.
    # Need to layout children of parent nodes so siblings are together.
    $col += int(($m_width[$tree{root}]/2));
    $table[$row][$col] = $tree{root};
    # Also put node's location into the %loc hash
    @{$loc{$tree{root}}} = ($row, $col); 
    $row+=2;
    my $offset;
    my $cumu_pos;
    my $siblings;
    for (my $xx=0; $xx<=$#generation; $xx++)
    {
        $col = 0;
        for (my $yy=0; $yy<=$#{$table[$row-2]}; $yy++)
        {
            #
            # Layout children in the order of the parents generation is layed out.
            # We always want to build a generation from the left, 
            # and just using @generation
            # won't meet that requirement.
            #
            if (defined($table[$row-2][$yy])) 
            {
                $parent = $table[$row-2][$yy];
            }
            else
            {
                next;
            }
            #
            # There might be a space saving optimization here
            # by checking row-2,col-1, and if nothing is there
            # then decrement $col.
            # 
            for (my $cc=0; $cc<=$#{$children{$parent}}; $cc++)
            {
                $node = $children{$parent}[$cc];
                $offset = int(($loc{$parent}[1] - ($m_width[$parent]/2)) 
                              + ($m_width[$node]/2));
                $cumu_pos = $col + int((($m_width[$node])/2));
                if ($cumu_pos < $offset)
                {
                    $col = $offset;
                }
                else
                {
                    $col = $cumu_pos
                }
                $table[$row][$col] = $node;
                # Also put node's location into the %loc hash
                @{$loc{$node}} = ($row, $col);          
                # Better to add the fraction on the right. 
                $col += int((($m_width[$node])/2)+0.5); 
            }
        }
        $row+=2;
    }
}

sub tile_color
{
    my @choices = ("#FFCCFF", "#FFCCCC", "#CCFFFF", "#CCFFCC", "#CCCCFF");
    my $gc = 0;                 # generation counter;
    my $prev_parent = -1;       # parent of the previous table entry
    for (my $xx = 0; $xx<=$#table; $xx++)
    {
        for (my $yy = 0; $yy<=$#{$table[$xx]}; $yy++)
        {
            if (defined($table[$xx][$yy]))
            {
                # special case for the root
                if (($parent{$table[$xx][$yy]} != $prev_parent) || 
                    ($table[$xx][$yy] == 0))
                {
                    # print "p: $parent{$table[$xx][$yy]} pp: $prev_parent\n";
                    $gc++;
                    $prev_parent = $parent{$table[$xx][$yy]};
                }
                $colors[$xx][$yy] = $choices[$gc%5];
                # print "$xx, $yy: " . $gc%5 . " $colors[$xx][$yy]\n";
            }
        }
        # $gc++ # increment every time we change a row, 
        # since the generation changes as well.
    }
}

sub tile_connect
{
    # @table is a global
    my $tmax = 0;
    my $px;
    my $py;
    for (my $xx=0; $xx<=$#table; $xx++)
    {
        if ($#{$table[$xx]} > $tmax)
        {
            $tmax = $#{$table[$xx]};
        }
    }
    for (my $xx=0; $xx<=$#table; $xx++)
    {
        for (my $yy=0; $yy<=$tmax; $yy++)
        {
            if ($table[$xx][$yy] > $tree{root})
            {
                my $parent = $parent{$table[$xx][$yy]};
                $px = $loc{$parent}[0];
                $py = $loc{$parent}[1];
                # print "$xx, $yy $table[$xx][$yy] parent: $px $py\n";
                if ($py == $yy)
                {
                    $table[$xx-1][$yy] = "<img src=\"15a.gif\">";
                }
                elsif ($py <= ($yy-1))
                {
                    if ($py < ($yy-1))
                    {
                        $table[$xx-2][$yy-1] = "<img src=\"74.gif\">";
                        for (my $pp=2; $py < $yy-$pp; $pp++)
                        {
                            # if it already contains an img 74.gif then replace with 7374.gif
                            if ($table[$xx-2][$yy-$pp] =~ m/74\.gif/)
                            {
                                $table[$xx-2][$yy-$pp] = "<img src=\"7374.gif\">";
                            }
                            else
                            {
                                $table[$xx-2][$yy-$pp] = "<img src=\"73.gif\">";
                            }
                        }
                    }
                    $table[$xx-1][$yy] = "<img src=\"05a.gif\">";
                }
                elsif ($py >= ($yy+1))
                {
                    if ($py > ($yy+1))
                    {
                        if ($table[$xx-2][$yy+1] =~ m/img/)
                        {
                            $table[$xx-2][$yy+1] = "<img src=\"7336.gif\">";
                        }
                        else
                        {
                            $table[$xx-2][$yy+1] = "<img src=\"36.gif\">";
                        }
                        for (my $pp=2; $py > $yy+$pp; $pp++)
                        {
                            # if we already have image 36.gif then replace with 7336.gif
                            if ($table[$xx-2][$yy+$pp] =~ m/36\.gif/)
                            {
                                $table[$xx-2][$yy+$pp] = "<img src=\"7336.gif\">";
                            }
                            else
                            {
                                $table[$xx-2][$yy+$pp] = "<img src=\"73.gif\">";
                            }
                        }
                    }
                    $table[$xx-1][$yy] = "<img src=\"25a.gif\">";
                }
            }
        }
    }
}

sub render_html
{
    my $selected_node_pk = shift;
    my $ro = shift;
    my $node_select;
    # @table is a global
    
    my $html;
    my $tmax = 0;
    for (my $xx=0; $xx<=$#table; $xx++)
    {
        if ($#{$table[$xx]} > $tmax)
        {
            $tmax = $#{$table[$xx]};
        }
    }
    my $at_width = 75 * $tmax;
    my $outer_width = $at_width+300;
    $html .= "<table width=\"$at_width\" border=\"0\" cellpadding=\"0\" cellspacing=\"4\">";
    for (my $xx=0; $xx<=$#table; $xx++)
    {
        # make sure the row is 75 pixels tall.
        $html .= "\n<tr><td><img src=\"white.gif\" width=\"5\" " .
        " height=\"75\"></td>\n";
        for (my $yy=0; $yy<=$tmax; $yy++)
        {
            if (defined($table[$xx][$yy]))
            {
                my $node = $table[$xx][$yy];
                if ($node =~ m/img/)
                {
                    $html .= "<td width=\"75\">$node</td>\n";
                }
                else
                {
                    my $color;
                    my $pre_cell = "";
                    my $post_cell = "";
                    $node_select = "node_select";
                    if ($node == $selected_node_pk)
                    {
                        $color = "#FFD700";
                        $pre_cell .= "<div align=\"center\">Root</div>";
                        $post_cell=""; 
                    }
                    else
                    {
                        $color =  "#CCFFCC";
                    }
                    $html .= "<td width=\"75\" border=\"0\" bgcolor=\"$color\"> " .
                    "$pre_cell";
                    $html .= "<div align=\"center\">node $node</div>";

                    # $tree{$node}[4] =~ /(.*)_\d+$/;
                    # my $kindroot = $1;
                    # $html .= "<table border=\"0\" width=\"100%\"><tr><td " .
                    # "width=\"50%\"><div align=\"left\">$del_string</div></td><td " .
                    # " width\"50%\"></td></tr></table>\n";
                    # $html .= "<div align=\"center\"><font size=\"-1\"><a " .
                    # "href=\"../doc.cgi?file=site/webtools/analysis/" .
                    # "$kindroot/$tree{$node}[4].html&tree_pk=$tree{tree_pk}\">" .
                    # "$tree{$node}[0]</a>\n";
                    # $html .= "</font></div>$post_cell</td>\n";
                    $html .= "</td>\n";
                }
            }
            else
            {
                $html .= "<td width=\"75\">&nbsp;</td>\n";
            }
        }
        $html .= "</tr>\n";
    }
    $html .= "</table>\n";
    return $html;
}

sub render_at
{
    my $selected_node_pk = shift;
    my $ro = shift;
    
    pass1();                    # creates @table, @loc
    pass2();                    # modifies @table, @loc fixing mis-aligned zeroth row nodes
    tile_color();               # reads @table, creates @colors
    tile_connect();             # modifies @table adding img tags, reads @loc
    my $html = render_html($selected_node_pk, $ro); # reads @table, @colors
    return $html;
}


sub get_all_subs_vals
{
    my ($dbh, $us_fk, $chref) = @_;
    my %ch = %$chref;
    my $confref = get_all_config_entries($dbh);
    @ch{keys %$confref} = values %$confref;
    $ch{geoss_dir} = $GEOSS_DIR; $ch{version} = $VERSION;
    $ch{message} .= get_stored_messages($dbh, $us_fk);
    $ch{footer_login} = doq($dbh, "get_login", $us_fk);
    my $sth = getq("get_user_type", $dbh, $us_fk);
    $sth->execute();
    ($ch{footer_type}) = $sth->fetchrow_array();
    $ch{footer_type} = "Array Center Staff" if ($ch{footer_type} eq "curator");
    $ch{footer_type} = "Public" if ($ch{footer_type} eq "public");
    $ch{footer_type} = "Administrator" if ($ch{footer_type} eq "administrator");
    $ch{footer_type} = "Member User" 
    if ($ch{footer_type} eq "experiment_set_provider");

    $sth->finish(); 
    my $url = index_url($dbh);

    # strip the last dir, which is admintools, webtools, or public_data
    $url =~ /(.*)\/.*/;
    my $web_index = "$1/webtools";
    my $admin_index = "$1/admintools";
    my $org_index = "$1/orgtools";
    my $cur_index = "$1/curtools";

    $ch{member_home} = $web_index;
    $ch{logout_url} = "$web_index/logout.cgi";
    if (is_administrator($dbh, $us_fk))
    {
        $url = index_url($dbh);
        $ch{admin_home} = "<a href=\"$admin_index\">Admin Home</a>&nbsp;";
        $ch{org_home} = "<a href=\"$org_index\">Center Home</a>&nbsp;";
    }
    if ((is_curator($dbh, $us_fk)) && get_config_entry($dbh, "array_center"))
    {
        $url = index_url($dbh);
        $ch{cur_home} = "<a href=\"$cur_index\">Array Center Staff Home</a>&nbsp;";
    }
    if ((is_org_curator($dbh, $us_fk)) && get_config_entry($dbh, "array_center"))
    {
        $url = index_url($dbh);
        $ch{org_home} = "<a href=\"$org_index\">Center Home</a>&nbsp;";
    }
    if ((defined $ch{linkurl1}) && (defined $ch{linktext1}))
    {
        $ch{link1} = "<a href=\"$ch{linkurl1}\">$ch{linktext1}</a>&nbsp;"; 
    }
    return (\%ch);
}


# can be used for files that don't need readtemplate
# combines getting all stored messages and getting the configuration information
# with reading the input file and substituting
sub get_allhtml_orig
{
    my ($dbh, $us_fk, $htmlfile, $headerfile, $footerfile, $chref) = @_;
    my %ch = %{get_all_subs_vals($dbh, $us_fk, $chref)};
    my $allhtml = readfile($htmlfile, $headerfile, $footerfile);

    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    return $allhtml;
}

# This routine will read in a file (typically an html one).
# It will iprepend/append the specified header and footer files.  Pass an empty
# string or null if header/footer added to file is not desired.
sub readfile_orig
{
    my ($infile, $headerfile, $footerfile) = @_;
    my $temp;
    my $header = "";
    my $footer = "";
    #
    # 2003-01-10 Tom:
    # It is possible that someone will ask us to open a file with a leading space.
    # That requires separate args for the < and for the file name. I did a test to confirm
    # this solution. It also works for files with trailing space.
    # 
    # open(IN, "<", "$_[0]");
    # Keep the old style, until the next version so that we don't have to retest everything.
    # 
    my @stat_array = stat($infile);
    if ($#stat_array < 7)
    {
        die "File $_[0] not found\n";
    }
    open(IN, "<", $infile);
    sysread(IN, $temp, $stat_array[7]) ||
    die "Couldn't open $temp: $!";
    close(IN);
    my $path = $WEB_DIR;  
    if ((defined $headerfile) || ($headerfile ne ""))
    {
        @stat_array = stat("$path/$headerfile");
        if ($#stat_array < 7)
        {
            die "File $path/$headerfile not found\n";
        }
        open(IN, "<", "$path/$headerfile") || 
        die "Couldn't open $path/$headerfile: $!";
        sysread(IN, $header, $stat_array[7]);
        close(IN);
    }
    if ((defined $footerfile) || ($footerfile ne ""))
    {
        @stat_array = stat("$path/$footerfile");
        if ($#stat_array < 7)
        {
            die "File $footerfile not found\n";
        }
        open(IN, "<", "$path/$footerfile") ||
        die "Couldn't open $path/$footerfile: $!";
        sysread(IN, $footer, $stat_array[7]);
        close(IN);
    }
    $temp =  $header . $temp . $footer;
    return $temp;
}

sub readfile
{
    my ($infile) = @_;
    my $temp;

    my @stat_array = stat($infile);
    if ($#stat_array < 7)
    {
        die "File $_[0] not found\n";
    }
    open(IN, "<", $infile);
    sysread(IN, $temp, $stat_array[7]) ||
    die "Couldn't open $temp: $!";
    close(IN);
    return $temp;
}

sub get_allhtml
{
    my ($htmlfile, $chref) = @_;
    my %ch = %$chref;           # See get_all_subs_vals
    my $allhtml = readfile($htmlfile);

    $allhtml =~ s/{(.*?)}/$ch{$1}/g;
    return $allhtml;
}



main:
{
    # my $q = new CGI;

    my $tree_pk = 1;
    # my $tree_pk = $q->param("tree_pk");
    # my %ch = $q->Vars();
    my %ch;
    # my $dbh = new_connection();
    
    # us_fk is user foreign key?
    # my $us_fk = get_us_fk($dbh, "webtools/choose_tree.cgi");

    foreach my $key (keys(%ch))
    {
        if ($key =~ m/edit_(\d+)\.x/)
        {
            $ch{node_pk} = $1;
        }
    }

    # Side effecty. Populates @generation, %parent, @children
    # my %tree = read_db($dbh, $tree_pk, $us_fk);
    my %tree = read_db();

    # my $condition = "tree_pk = $tree_pk";
    # if (! getq_can_write_x($dbh, $us_fk, "tree", "tree_pk", $condition))
    # {
    #   warn "Can't write tree";
    #   if (getq_can_read_x($dbh, $us_fk, "tree", "tree_pk", $condition))
    #   {
    #     $ch{readonly} = 1; 
    #   }
    #   else
    #   {
    #     set_session_val($dbh, $us_fk, "message", "errmessage",
    #         get_message("INVALID_PERMS"));
    #     my $url = index_url($dbh, "webtools"); # see session_lib
    #       print "Location: $url\n\n";
    #     exit();
    #   }
    # }

    if (! exists($ch{node_pk}))
    {
        $ch{node_pk} = $tree{root};
    }


    #
    # Most analysis tree subroutines are in lib/geoss_analysis_tree_lib.pl.
    # - Render the tree (an html table?)
    # - Create the drop down list with available analyses (supposedly correct
    # contextually based on the currently selected node).
    # - Create table with user params displayed nice.
    # - Create the select drop down menu for appropriate input files.
    #
    my $atree = render_at($ch{node_pk}, $ch{readonly});

    # skip UI that lets users select analyses and other stuff.
    # my $select_node = select_node($dbh, $us_fk, $ch{node_pk});
    # $ch{add_node_html} = set_add_node_html($select_node) 
    # if (($select_node =~ /option/) &&
    #     (! $ch{readonly}));

    my $properties = "";        # build_properties($ch{node_pk}, $ch{readonly}); 

    if ($ch{readonly})
    {
        $ch{htmltitle} = "View Analysis Tree";
        $ch{htmldescription} = "Use this page to view analysis tree settings."
        . "  To view parameters for a specific node, click on the pencil " .
        " graphic associated with the node";
    }
    else
    {
        $ch{htmltitle} = "Edit Analysis Tree";
        # $ch{help} = set_help_url($dbh, "edit_or_delete_or_run_an_existing_analysis_tree");
        $ch{htmldescription} = "Click the pencil graphic of the node you wish to select.  You may then delete the selected node, modify the selected node's parameters, add a child node from the selected node, or run the tree from that node downward. Scroll down for detailed instructions.";
    }
    $ch{tree_pk} = $tree_pk;
    $ch{tree_name} = $tree{tree_name};
    $ch{root} = $tree{root};
    $ch{atree} = $atree;
    $ch{properties} = $properties;

    # my $tree = GEOSS::Analysis::Tree->new(pk => $tree_pk);

    # $tree->root is a node
    # $tree is a hashref
    my $tree = {pk => 1,
                name => "demo",
                status => "CURRENT",
                root => {pk => 1,
                         tree => 1,
                         parent => -1}};
    $ch{status} = $tree->{status};

    # if ($ch{status} eq "OBSOLETE")
    # {
    #     $ch{action} = '<td>
    #   <input type="submit" name="upgrade" value="Upgrade Tree">
    #   </td>
    #   <td>
    #   <input type="submit" name="copy" value="Copy Tree">
    #   </td>';
    #     set_return_message($dbh, $us_fk, "message", "warnmessage",
    #                        "TREE_OBSOLETE");
    # }
    # else
    # {
    #     $ch{action} = '<td>&nbsp;</td>
    #   <td><input type="submit" name="run" value="Run Analysis"></td>';
    # }

    my $owner='generic-owner';
    # my ($owner, undef) = getq_owner_group_by_pk($dbh, $ch{tree_pk});

    my $login = "generic-user";
    my $dir = "Analysis_Trees/$ch{tree_name}";

    # if possible, link to the input file
    my $filename = "demo-filename"; # $tree->input->name;
    if (-e $filename)
    {
        $ch{view_input} = qq#<a href="getfile.cgi?filename=$filename">
      View input file (# . basename($filename) . qq#)</a>#;
    }
    if (-d $dir)
    {
        $ch{view_results} = qq#<a
      href="files2.cgi?analysis=$ch{tree_pk}&submit_analysis=1">
      View tree results</a>#;
    }
    else
    {
        $ch{view_results} = "&nbsp";
    }
    my $infile = "atree_template.html";
    $infile = "view_atree1.html" if ($ch{readonly});
    my $all_html = get_allhtml($infile, \%ch);

    # print "Content-type: text/html\n\n$all_html";
    print "$all_html\n";
}
