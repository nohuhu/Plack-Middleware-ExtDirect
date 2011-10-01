use Plack::Builder;

builder {
    enable 'Static',    path => qr{(gif|jpg|png|js|css|html)$},
                        root => './htdocs/';

    enable 'ExtDirect', api_path    => 'php/api.php',
                        router_path => 'php/router.php',
                        poll_path   => 'php/poll.php',
                        debug       => 1,
                        ;

    sub {[ 301,
         [
            'Content-Type' => 'text/plain',
            'Location'     => 'http://localhost:5000/index.html',
         ],
         [ 'Moved permanently' ]
         ]};
}
