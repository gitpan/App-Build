
package App::Build;

use App::Options;
use Module::Build;
use Cwd ();
use File::Spec;
use Sysadm::Install qw(:all);

# until I get to 1.0, I will update the version number manually
$VERSION = "0.10";
#$VERSION = do { my @r=(q$Revision: 1.4 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r};

@ISA = ("Module::Build");

use strict;

delete $ENV{PREFIX};   # Module::Build protests if this var is set

=head1 NAME

App::Build - a base/default class for building/installing applications

=head1 SYNOPSIS

  This module is used within a Build.PL script directly or
  it can be subclassed to provide extra capabilities.

  use App::Build;

  shift(@ARGV) if ($#ARGV > -1 && $ARGV[0] eq "Build");

  my $build = App::Build->new (
      dist_name         => "App-Build",
      dist_version_from => "lib/App/Build.pm",
      dist_author       => "stephen.adkins\@officevision.com",
      extra_dirs        => [ "htdocs", "cgi-bin", "etc", "var" ],
      license           => "perl",
      build_requires => {
          "App::Build"  => 0,  # needed for installing the software
      },
  );
  
  $build->create_build_script;

=head1 DESCRIPTION

The vision of App::Build is to make installing entirely
functional perl applications (particularly web applications)
as easy as installing individual models from CPAN.

An ISP customer (or other unprivileged user)
who has shell access should be able to install any number
of available applications from CPAN simply by typing the
usual

  perl -MCPAN -e "install App-Build-Foo"

and the "Foo" application is installed on his account.

The goal is to make installing entire perl applications
as easy as installing a simple set of modules.
App::Build is a subclass of Module::Build.

App::Build does this by implementing the following features.

1. Distributions that use App::Build instead of Module::Build
can easily install files to other places, besides just
"lib" and "bin".  e.g. "htdocs", "cgi-bin", "etc".
(see the "extra_dirs" argument in the example in the Synopsis
above)

2. App::Build also adds a hook into the "install" action to
call the "configure()" method.  If you are subclassing
App::Build, you can override this method and perform
customized configuration tasks.

=head1 INCLUDED APPLICATIONS AND EXTERNAL APPLICATIONS

Although the distribution primarily supports the deployment
of an application whose files are included in the distribution,
it also supports deployment of applications which are not
included or are not on CPAN at all.

Anyone who finds a useful perl application somewhere 
(i.e. "Foo") can write a small perl distribution called
App-Build-Foo and upload it to CPAN.
When someone uses the CPAN shell, they can install the
application simply by typing

 install App-Build-Foo

Within the App-Build-Foo distribution would be a module,
App::Build::Foo, which would be a subclass of App::Build.
It would contain any specific logic necessary to download
and install the Foo application.

All applications installed with App::Build (and its
derivatives) should conform to a set of standards (see
below) so that when multiple applications are installed,
they are integrated seamlessly and work side by side.

=head1 APPLICATION INSTALLATION REQUIREMENTS

The following are the requirements of all App::Build
installations.

 * The installation MUST be useful to ISP's (internet
   service providers) and ASP's (application service
   providers) such that the software is installed
   in such a way that each customer of theirs may use
   it without any interactions with other customers.

 * The installation SHOULD allow for multiple versions
   even for an unprivileged user (an ISP/ASP customer).
   This allows a user to install a new version of an
   application and evaluate it and run it in parallel
   with an existing version of the application.

=head1 APPLICATION INSTALLATION STANDARDS

The following are additional standards of all App::Build
installations.

 * TBD

=head1 App::Build CONFIGURABILITY

Since App::Build uses App::Options, App::Options strips off all
of the --var=value options out of @ARGV and makes them available
via the global %App::options hash.

At build/install time, Build.PL (using Module::Build) is 
configurable using VAR=VALUE pairs on the command line.

(more on this later)

=cut

######################################################################
# BUILD: enhancements to "perl Build.PL"
######################################################################

=head1 METHODS

The documentation of the methods below is not for users of the
App::Build module (who are writing Build.PL scripts), but for people
interested in the internals of how App::Build extends Module::Build.

It is also so that I can remember what I was doing so that if the
internals of Module::Build change, I can maintain this code.

=head2 new()

We override the new() method in order to enhance the install paths.

In the future, we may also download and unpack external perl 
distributions.

=cut

sub new {
    my ($class, %args) = @_;
    #print "new($class, {", join(",",%args), "})\n";

    my $obj = $class->SUPER::new(%args);

    my $dist_name = $args{dist_name};
    if (!$dist_name) {
        die "must provide a dist_name" if ($dist_name eq "App-Build");
    }

    $obj->_enhance_install_paths();

#    my $tag = lc($dist_name);
#    $tag =~ s/^app-build-//;
#
#    my $url  = $App::options{"$tag.url"};
#    ($url) || die "URL [$tag.url] does not exist";
#
#    my $file = $App::options{"$tag.file"};
#    if (!$file) {
#        $file = $url;
#        $file =~ s!.*/!!;
#    }
#    ($file) || die "File [$tag.file] does not exist";
#
#    my $subdir = $App::options{"$tag.subdir"};
#    if (!$subdir) {
#        $subdir = $file;
#        $subdir =~ s!\.tar.gz$!!;
#        $subdir =~ s!\.tgz$!!;
#    }
#    ($subdir) || die "Subdir [$tag.subdir] does not exist";
#
#    my $prefix = $App::options{install_prefix} || $App::options{prefix};
#    my $archive_dir = $App::options{archive_dir} || "archive";
#    mkdir($archive_dir) if (! -d $archive_dir);
#
#    my $archive = "$archive_dir/$file";
#
#    (-d $archive_dir) || die "Archive Directory [$archive_dir] does not exist";
#    (-w $archive_dir) || die "Archive Directory [$archive_dir] not writeable";
#
#    $class->mirror($url, $archive);
#    $class->unpack($archive, "unpack", $subdir);

    #print "new() = $obj\n";
    #print "obj = {", join(",", %$obj), "}\n";
    #print "obj{properties} = {", join(",", %{$obj->{properties}}), "}\n";

    return($obj);
}

=head2 _app_tag()

This lowercase-ifies the dist_name, removes "app-build-" from the front,
and returns it as the "application tag".
Therefore, a distribution called "App-Build-Kwiki" would have an
"app_tag" of "kwiki".  An "app_tag" is used for looking up configuration
settings in the %App::options hash produced by App::Options.

=cut

sub _app_tag {
    my ($self) = @_;
    my $dist_name = $self->dist_name();
    my $tag = lc($dist_name);
    $tag =~ s/^app-build-//;
    return($tag);
}

=head2 _prefix()

This returns the "install_base" property if it was supplied on the command
line. i.e.

   perl Build.PL install_base=/usr/mycompany/prod

or (synonymously) ...

   perl Build.PL PREFIX=/usr/mycompany/prod

If the install_base was not supplied, the "prefix" out of perl's own
Config.pm is returned.  So if perl is installed in "/usr/local/bin", then
"/usr/local" is returned.
If perl is installed in "/usr/bin", then "/usr" is returned.

=cut

sub _prefix {
    my ($self) = @_;
    my $prefix = $self->{properties}{install_base} || $self->{config}{prefix};
    return($prefix);
}

=head2 _enhance_install_paths()

The install_sets (core, site, vendor) as set from values in perl's own
Config.pm are enhanced to include the absolute directories in which
the extra_dirs will be installed.

=cut

sub _enhance_install_paths {
    my ($self) = @_;
    my $properties = $self->{properties};
    my $install_sets = $properties->{install_sets};
    my @extra_dirs = $self->_get_extra_dirs();
    my $prefix = $self->_prefix();
    my $tag = $self->_app_tag();
    my ($path);
    foreach my $dir (@extra_dirs) {
        $path = $App::options{"$tag.$dir.dir"} || File::Spec->catdir($prefix, $dir);
        $install_sets->{core}{$dir}   = $path;
        $install_sets->{site}{$dir}   = $path;
        $install_sets->{vendor}{$dir} = $path;
    }
}

######################################################################
# BUILD: enhancements to "./Build"
######################################################################

=head2 ACTION_code()

We override ACTION_code() to copy additional directories of files
needed to install the application.

When you invoke "./Build", the method $self->ACTION_build() gets
called on this object.  This, in turn, calls $self->ACTION_code()
and $self->ACTION_docs().  Each of these methods copies files into
the "blib" subdirectory in preparation for installation.

=cut

sub ACTION_code {
    my ($self) = @_;
    $self->SUPER::ACTION_code(); # call this first (creates "blib" dir if necessary)
    $self->process_app_files();  # NEW. call this to copy "extra_libs" to "blib"
}

=head2 _added_to_INC()

We override this method to ensure that "lib" (libraries to be installed)
is added to the front of @INC.
This is because we often want to use the (latest) enclosed module as
the installing module, even if it has already been installed.

=cut

sub _added_to_INC {
  my $self = shift;
  my %seen;
  $seen{$_}++ foreach $self->_default_INC;
  unshift(@INC,"lib");
  return grep !$seen{$_}++, @INC;
}

=head2 _get_extra_dirs()

Gets the list of extra_dirs to be installed.

The extra_dirs may be specified in the Build.PL in
a variety of ways.
It can be a scalar (comma-separated list of directories),
an array ref of directories, or a hash ref where the
keys are the directories.

If extra_dirs is specified with a hash ref, the hash values
are hashrefs of attributes. i.e.

   extra_dirs => {
       var => {
           dest_dir => "var",
       },
       htdocs => {
           dest_dir => "htdocs",
       },
   },

So far, only the "dest_dir" attribute is defined.

=cut

sub _get_extra_dirs {
    my ($self) = @_;
    my $properties = $self->{properties};
    my @extra_dirs = ();
    if ($properties->{extra_dirs}) {
        if (ref($properties->{extra_dirs}) eq "ARRAY") {
             @extra_dirs = @{$properties->{extra_dirs}};
        }
        elsif (ref($properties->{extra_dirs}) eq "HASH") {
             @extra_dirs = (sort keys %{$properties->{extra_dirs}});
        }
        elsif (ref($properties->{extra_dirs})) {
             die "extra_dirs can be a scalar, array ref, or hash ref, but not " . ref($properties->{extra_dirs});
        }
        else {
             @extra_dirs = split(/,/,$properties->{extra_dirs});
        }
    }
    return(@extra_dirs);
}

=head2 _get_extra_dirs_attributes()

Gets the hash of all extra_dirs attributes.

=cut

sub _get_extra_dirs_attributes {
    my ($self) = @_;
    my $properties = $self->{properties};
    my @extra_dirs = ();
    my ($extra_dirs);
    if ($properties->{extra_dirs}) {
        if (ref($properties->{extra_dirs}) eq "ARRAY") {
             @extra_dirs = @{$properties->{extra_dirs}};
             $extra_dirs = { map { $_ => { dest_dir => $_ } } @extra_dirs };
        }
        elsif (ref($properties->{extra_dirs}) eq "HASH") {
             @extra_dirs = (sort keys %{$properties->{extra_dirs}});
             $extra_dirs = $properties->{extra_dirs};
        }
        elsif (ref($properties->{extra_dirs})) {
             die "extra_dirs can be a scalar, array ref, or hash ref, but not " . ref($properties->{extra_dirs});
        }
        else {
             @extra_dirs = split(/,/,$properties->{extra_dirs});
             $extra_dirs = { map { $_ => { dest_dir => $_ } } @extra_dirs };
        }
    }
    return($extra_dirs);
}

=head2 process_app_files()

During "./Build" (which calls ACTION_code()), the process_app_files()
method copies files from the extra_dirs to their appropriate
locations under "blib".

=cut

sub process_app_files {
    my ($self) = @_;
    my ($path, $files);

    my @extra_dirs = $self->_get_extra_dirs();
    # print "process_app_files(): extra_dirs=[@extra_dirs]\n";

    my $blib = $self->blib;
    foreach my $dir (@extra_dirs) {
        if (-d $dir) {
            $path = File::Spec->catfile($blib, $dir), 
            File::Path::mkpath($path);
            $files = $self->_find_all_files($dir);
            while (my ($file, $dest) = each %$files) {
                $self->copy_if_modified(from => $file, to => File::Spec->catfile($blib, $dest) );
            }
        }
    }
}

=head2 _find_all_files()

This is used by process_app_files() to get the list of files under "extra_dirs"
to copy to "blib".

=cut

sub _find_all_files {
    my ($self, $dir) = @_;
    return {} unless -d $dir;
    return { map { $_, $_ } @{ $self->rscan_dir($dir, sub { $_ !~ /(CVS|RCS|SCCS)/ }) } };
}

######################################################################
# INSTALL: enhancements to "./Build install"
######################################################################

=head2 install_base_relative()

This method is overridden to indicate that the relative directory
of an "extra_dir" is the same as the dir/type itself.

=cut

sub install_base_relative {
    my ($self, $type) = @_;
    my $extra_dirs = $self->_get_extra_dirs_attributes();
    my ($reldir);
    if ($extra_dirs->{$type}) {
        $reldir = $type;
    }
    elsif ($type eq "html") {
        $reldir = "htdocs/docs";
    }
    if (!$reldir) {
        $reldir = $self->SUPER::install_base_relative($type);
    }
    return($reldir);
}

=head2 install_map()

This method is only overridden in order to put in the fix so
that it creates a .packlist based on dist_name if the module_name
is not specified.

=cut

sub install_map {
  my ($self, $blib) = @_;
  $blib ||= $self->blib;

  my %map;
  foreach my $type ($self->install_types) {
    my $localdir = File::Spec->catdir( $blib, $type );
    next unless -e $localdir;

    if (my $dest = $self->install_destination($type)) {
      $map{$localdir} = $dest;
    } else {
      # Platforms like Win32, MacOS, etc. may not build man pages
      die "Can't figure out where to install things of type '$type'"
        unless $type =~ /^(lib|bin)doc$/;
    }
  }

  if ($self->create_packlist) {
    # Write the packlist into the same place as ExtUtils::MakeMaker.
    my $archdir = $self->install_destination('arch');
    my @ext = split /::/, $self->module_name;
    if ($#ext == -1) {              # FIX
        @ext = ($self->dist_name);  # FIX
    }                               # FIX
    $map{write} = File::Spec->catfile($archdir, 'auto', @ext, '.packlist'); # FIX ?!?
  }

  if (length(my $destdir = $self->{properties}{destdir} || '')) {
    foreach (keys %map) {
      # Need to remove volume from $map{$_} using splitpath, or else
      # we'll create something crazy like C:\Foo\Bar\E:\Baz\Quux
      my ($volume, $path) = File::Spec->splitpath( $map{$_}, 1 );
      $map{$_} = File::Spec->catdir($destdir, $path);
    }
  }

  $map{read} = '';  # To keep ExtUtils::Install quiet

  return \%map;
}

=head2 ACTION_install()

This method is overridden to put in the configure() hook so that
a module which extends App::Build can implement the configure()
method.  Then the configure() method will run when 
"./Build install" is invoked.

=cut

sub ACTION_install {
    my ($self) = @_;
    require ExtUtils::Install;
    $self->depends_on('build');
    my $map = $self->install_map;
    ExtUtils::Install::install($map, 1, 0, $self->{args}{uninst}||0);
    $self->configure();
}

=head2 configure()

Do nothing.  This method is a hook that can be overridden by a 
subclass of App::Build.
The idea is that after installing files, you might need to run additional
code to configure the application.

=cut

sub configure {
    my ($self) = @_;
    # Do nothing.  This is a hook for overriding in a subclass.
}

=head1 ACKNOWLEDGEMENTS

 * Author:  Stephen Adkins <stephen.adkins@officevision.com>
 * License: This is free software. It is licensed under the same terms as Perl itself.

=head1 SEE ALSO

=cut

1;

__END__

# NO LONGER USED: using Sysadm::Install instead

#=head2 mirror()

    * Signature: App::Build->mirror($url, $file);
    * Param:  $url          string
    * Param:  $file         string
    * Since:  0.50

#=cut

sub mirror {
    my ($class, $url, $file) = @_;
    if (! -f $file) {
        print "Mirroring $url to $file\n";
        system("wget -O $file $url");
    }
    else {
        print "Mirrored file $file up to date\n";
    }
}

#=head2 unpack()

    * Signature: App::Build->unpack($archive_file, $directory, $subdir);
    * Param:  $archive_file string
    * Param:  $directory    string
    * Param:  $subdir       string
    * Since:  0.50

#=cut

sub unpack {
    my ($class, $archive_file, $directory, $subdir) = @_;
    my $verbose = $App::options{verbose};
    $directory ||= "$App::options{install_prefix}/src";
    mkdir($directory) if (! -d $directory);
    die "Directory $directory does not exist and can't be created" if (! -d $directory);

    my $start_dir = Cwd::getcwd();
    if (! File::Spec->file_name_is_absolute($archive_file)) {
        $archive_file = File::Spec->catfile($start_dir, $archive_file);
    }

    chdir($directory);
    if ($subdir && -d $subdir) {
        print "Removing preexisting directory $subdir ...\n" if ($verbose);
        system("rm -rf $subdir");
        print "Removing done.\n" if ($verbose);
    }
    print "Unpacking $archive_file ...\n" if ($verbose);

    # my $archive = Archive::Any->new($archive_file);
    # $archive->extract;
    # my @files = $archive->files;
    # my $type = $archive->type;
    # $archive->is_impolite;
    # $archive->is_naughty;

    if ($archive_file =~ /\.zip$/) {
        system("unzip $archive_file");
    }
    elsif ($archive_file =~ /\.tar\.gz$/ || $archive_file =~ /\.tgz$/) {
        system("tar xvzf $archive_file");
    }
    else {
        die "Unknown archive type: $archive_file\n";
    }

    print "Unpacking done.\n" if ($verbose);

    die "Subdirectory $subdir not created" if (! -d $subdir);

    chdir($start_dir);
}

