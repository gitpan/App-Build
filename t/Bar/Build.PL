
use App::Build;

my $build = App::Build->new (
    dist_name         => "Bar",
    dist_version      => "0.99",
    dist_author       => "mattia.barbon\@libero.it",
    dist_abstract     => "A test Build.PL",
    license           => "perl",
    build_requires => {
        "App::Build"     => 0,
    },
    extra_dirs => { "lib", => { dest_dir => "lib/perl" } },
    install_base => '../test_install/remapped',
    create_packlist => 0,
);

$build->create_build_script;
