# BasHTTPd
*A janky web server written in Bash*

![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)
[![GitHub version](https://badge.fury.io/gh/AjankeFoundation%2Fbashttpd.svg)](https://badge.fury.io/gh/AjankeFoundation%2Fbashttpd)
![Jankiness](https://img.shields.io/badge/bash-3.2+-orange.svg)

- [![Build Status](https://travis-ci.org/AjankeFoundation/bashttpd.svg?branch=master)](https://travis-ci.org/AjankeFoundation/bashttpd) for *Master* branch
- [![Build Status](https://travis-ci.org/AjankeFoundation/bashttpd.svg?branch=develop)](https://travis-ci.org/AjankeFoundation/bashttpd) for *Develop* branch

Requirements
-------------

   1. `bash` (v3.2 required, v4 preferred) and a handful of POSIX utils
   2. `bashttpd.sh` to listen for requests
   3. `tcpserver` to bind it to a port
   4. A healthy dose of insanity :-D
  
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

  # This binds `bashttpd` to the local interface on port 2274, and backgrounds (`bg`/`&`) the process; limits to 16 conns

          Bash v3: $ tcpserver -c 16 127.0.0.1 2274 ./bashttpd &
          Bash v4: $ ./bashttpd.sh start 
    
  # This binds `bashttpd` to a private network IP on port 2274, and `bg`s the process; no conn limit

          Bash v3: $ tcpserver 192.168.0.5 2274 ./bashttpd &
          Bash v4: $ ./bashttpd.sh start -i 192.168.0.5 -c 9999
    
  # This bind `bashttpd` to all interfaces on port 80, (both public & private), with a 32 conn limit; NOT recommended!

          Bash v3: $ tcpserver -c 32 0.0.0.0 80 ./bashttpd &
          Bash v4: $ ./bashttpd.sh -c 32 -i 0.0.0.0 -p 80

Getting started
----------------

  1. Download/copy `bashttpd.sh` and install `tcpserver`.
  
      If you are installing `tcpserver` on Debian, the `ucspi-tcp` package it comes in is available via the base repos.

         apt-get update
         apt-get install ucspi-tcp

      If you are installing `tcpserver` on Mac OS X:
      
          brew update
          brew install ucspi-tcp
          
  2. Make sure you have Bash v3 or higher, Bash v4 is preferred. If not, you can install `bash` via Homebrew, `apt-get`, etc.
  
          bash --version
          brew install bash  # via Homebrew on MacOS
          apt-get update & apt-get upgrade bash  # via apt-get on Debian-based systems
          
  3. Make sure the script is executable, and in your document root.
  
          chmod 664 ./bashttpd.sh
          mv ./bashttpd.sh ./your_docroot
  
  4. Start ./bashttpd; this will differ based on bash version:
  
          # Bash v3: 
            tcpserver 127.0.0.1 2274 ./bashttpd.sh
            
          # Bash v4:
            ./bashttpd start

  5. Test it in your browser or with `curl` by visiting the document root's URL
  
          http://127.0.0.1:2274

     You should see a content listing of your document root; bashttpd does not display an index file.
      
Features
---------

  1. Shows directory listings
  2. Renders plain text, HTML, CSS, and Javascript files (i.e. full web pages)
  3. Renders all images and other files supported by your browser if you have the UNIX `file` util installed

Limitations
------------

  1. Does not support authentication
  2. Only supports certain types of HTTP requests, for safety reasons (No POST, just GET & HEAD)
  3. Does not display index files automatically, you must refer them directly in URL

Warnings & Security
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
  
Graceful Degradation
----------

The server uses the concept of graceful degradation to gracefully downgrade it's feature set, when needed. Some features make not be possible at times due to the fact that the server uses a small handful of utilities behind the scenes to accomplish certain things. If a util is called that it is not installed, the server will downgrade to a less feature-rich variant of the util to accomplish a comparable result. Sometimes this means using a more common UNIX util, sometimes it means switching to pure Bash. As a last resort, `bashttpd` will fail and provide a precise error message explaining what is missing from the system.

Here is the current list of common UNIX utils used by the server:

`ps`  `cat`  `ls`  `file`  `killall` 

...see, nothing too crazy.
  
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
            
