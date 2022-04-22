#!/usr/bin/perl -cw
#
# You should check the syntax of this file before using it in an auto-install.
# You can do this with 'perl -cw mapping.cfg.pl' or by executing this file
# (note the '#!/usr/bin/perl -cw' on the first line).

our $maptable = [
    { 'Powered by \[HPE DEV Team\]\(https://hpedev.io\)' => '[{{ BRANDING }} Community Team]({{ BRANDINGURL }})' },
    { '\[HPE DEV Team\]\(https://hpedev.io\)' => '[{{ BRANDING }} Community Team]({{ BRANDINGURL }})' },
    { 'HPE DEV Team' => '{{ BRANDING }} Community Team' },
    { 'HPE DEV team' => '{{ BRANDING }} Community Team' },
    { 'collaborate with HPE DEV' => 'collaborate with {{ BRANDING }} Community Team' },
    { 'Welcome to the Hack Shack' => 'Welcome to the {{ BRANDINGWOD }} Hack Shack' },
    { 'HPE DEV Workshops-on-Demand' => '{{ BRANDINGWOD }} Workshops-on-Demand' },
    { 'HPE DEV workshop-on-demand' => '{{ BRANDINGWOD }} Workshops-on-Demand' },
    { 'HPE DEV Community' => '{{ BRANDING }} Community' },
    { 'HPE DEV GitHub' => '{{ BRANDING }} Community GitHub' },
    { 'HPE DEV background' => '{{ BRANDING }} Community background' },
    { 'HPE DEV portal' => '{{ BRANDING }} Portal' },
    { 'HPE DEV Logo' => 'Workshops-on-Demand Logo' },
    { 'HPE DEV Munch-and-Learn' => '{{ BRANDING }} Munch-and-Learn' },
    { 'HPE DEV Slack Workspace' => '{{ BRANDING }} Community Slack Workspace' },
    { 'HPE DEV blog' => '{{ BRANDING }} Community Blog' },
    { 'HackShack workshops' => '{{ BRANDINGWOD }} Workshops-on-Demand' },
    { 'HackShack Workshops' => '{{ BRANDINGWOD }} Workshops-on-Demand' },
    { 'HackShack Workshop' => '{{ BRANDINGWOD }} Workshop-on-Demand' },
    { 'HackShack Labs and Open labs' => '{{ BRANDINGWOD }} Workshops-on-Demand' },
    { 'Python 101 HackShack' => '[Python 101 {{ BRANDINGWOD }} Workshop-on-Demand](https://developer.hpe.com/hackshack/workshop/15)' },
    { 'Ansible101 HPE DEV Worshop-on-Demand' => '[Ansible 101 {{ BRANDINGWOD }} Workshop-on-Demand](https://developer.hpe.com/hackshack/workshop/31)' },
    { 'HackShack' => 'Workshop-on-Demand' },
    { 'HPE DEV Hack Shack team' => '{{ BRANDING }} Community Team' },
    { 'HPE DEV Hack Shack Workshops-on-Demand' => '{{ BRANDINGWOD }} Workshops-on-Demand' },
    { 'HPE DEV Hack Shack CSI Workshop' => '[{{ BRANDINGWOD }} CSI Workshop-on-Demand](https://developer.hpe.com/hackshack/workshop/2)' },
    { 'Hack Shack tenant' => '{{ BRANDING }} Greenlake Hack Shack tenant' },
    { 'Hack Shack Workshops ' => '{{ BRANDINGWOD }} Workshops-on-Demand' },
    { 'HPE DEV Hack Shack technical workshops' => '{{ BRANDINGWOD }} Workshops-on-Demand' },
    { 'HPE DEV Hack Shack Workshops-on-Demand' => '{{ BRANDINGWOD }} Workshops-on-Demand' },
    { '\!\[HPEDEVlogo\]\(Pictures/hpedevlogo-NB.JPG\)' => '{{ BRANDINGLOGO }}' },
    { '\!\[HPEDEVlogo\]\(Pictures/hpe-dev-logo.png\)' => '{{ BRANDINGLOGO }}' },
];
