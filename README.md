# BasHTTPd
*A janky web server written in Bash*

![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)
[![GitHub version](https://badge.fury.io/gh/AjankeFoundation%2Fbashttpd.svg)](https://badge.fury.io/gh/AjankeFoundation%2Fbashttpd)
![Jankiness](https://img.shields.io/badge/bash-3.2+-orange.svg)

- [![Build Status](https://travis-ci.org/AjankeFoundation/bashttpd.svg?branch=master)](https://travis-ci.org/AjankeFoundation/bashttpd) for *Master* branch
- [![Build Status](https://travis-ci.org/AjankeFoundation/bashttpd.svg?branch=develop)](https://travis-ci.org/AjankeFoundation/bashttpd) for *Develop* branch

Requirements
-------------

  1. `bash` (v3.2, v4 preferred)
  2. `bashttpd.sh`, `cat`, and `ls` are required, and a few other common utils are optional.
  3. `tcpserver` as the TCP engine.
  4. A healthy dose of insanity.

Example Usage
---------

    $ ./bashttpd start
      [INFO] Attempting to start bashttpd3 with the following settings.
      IP Address: 127.0.0.1
      Port: 2274
      Connection Limit: 16
      Process ID: 37580
      Document Root: /Users/codz/Documents

    $ curl 127.0.0.1:2274/hello_world.html
      <h1>Hello World!</h1>

Example Configurations
---------

- Bind bashttpd to local interface, port 2274, and background (bg/&) process; limit 16 conns
        Bash v3: $ tcpserver -c 16 127.0.0.1 2274 ./bashttpd &
        Bash v4: $ ./bashttpd.sh start 
- Bind bashttpd to a private network IP, port 2274, and bg process; no conn limit
        Bash v3: $ tcpserver 192.168.0.5 2274 ./bashttpd &
        Bash v4: $ ./bashttpd.sh start -i 192.168.0.5 -c 9999
- Bind bashttpd to all interfaces, on port 80, both public & private, with a 32 conn limit; NOT recommended!
        Bash v3: $ tcpserver -c 32 0.0.0.0 80 ./bashttpd &
        Bash v4: $ ./bashttpd.sh -c 32 -i 0.0.0.0 -p 80

Getting started
----------------

  1. Download/copy `bashttpd.sh` and install `tcpserver`.
  
      If you are installing on Debian, the `ucspi-tcp` package is available via the base repos.

	  apt-get update
	  apt-get install ucspi-tcp

      If you are installing on Mac OS X:
      
          brew update
          brew install ucspi-tcp
          
  2. Make sure you have Bash v3 or higher. If not, install via your package manager.
  
          bash --version
          brew install bash
          bash --version
          
  3. Make sure the script is executable, and in your document root.
  
          chmod 664 ./bashttpd.sh
          mv ./bashttpd.sh ./your_docroot
  
  4. Start ./bashttpd; this will differ based on bash version:
  
          Bash v3: tcpserver 127.0.0.1 2274 ./bashttpd.sh
          Bash v4: ./bashttpd start

  5. Test it in your browser or with curl by visiting the document root's URL
  
          http://127.0.0.1:2274

     You should see the contents of your document root; bashttpd does not display an index file.
      
Features
---------

  1. Shows directory listings
  2. Renders plain text, HTML, CSS, and Javascript files (i.e. full web pages)
  3. Renders all images and other files supported by your browser if you have `file` installed

Limitations
------------

  1. Does not support authentication
  2. Only supports certain types of HTTP requests, (No POST, just GET & HEAD)
  3. Does not display index files automatically, you must refer them directly in URL

Security
--------

  1. Do not use this in a public-facing environment.
  2. Do not use this in a production environment.
  3. The server rejects POST requests.
  4. Injection is always a threat, even though URI cleaning is performed.

HTTP protocol support
---------------------

  - 404: Returned when requested file/directory not found or inaccessible.
  - 403: Returned when a file is inaccessible to the user that ran the script.
  - 400: Returned when the first word of the first HTTP request line is not `GET` or `HEAD`.
  - 200: Returned with valid content.
  
Contributing
---------------------

As always, your patches/pull requests are welcome! Please make feature suggestions or pull requests on the `develop` branch. The project uses `git-flow-AVH`, and in turn, the Vincent Driessen's git workflow model for software development. You can read more about it [here](http://nvie.com/posts/a-successful-git-branching-model/).

Testimonials
------------

    "If anyone installs that anywhere, they might meet a gruesome end with a rusty fork"
                                                              - Avleen, BasHTTPd Creator

    "What is that? Wait a server written in bash. What an abomination!"
                                                      - anonymous "fan"
                                                      
    "With BasHTTPd, I was able to increase security 10-fold on my RHEL3 whitebox server. 
     Without all those viruses, I was able to pack another 100 websites onto my server,
     and decline my hosting provider's expensive Raspberry Pi upsell for another year;
     Thanks Ajanke Foundation!"                         - Webmaster, slumlordhosting.com
            
