# BasHTTPd
## *A janky web server written in Bash*

Requirements
-------------

  1. `bash` (v3 or higher) This ships with most OSes, including MacOSX.
  2. The `cat` and `ls` commands; no options/flags needed.
  3. `tcpserver`, `socat`, or `netcat` to handle tcp connections 
  4. A healthy dose of insanity

Examples
---------

Output of `head ./bashttpd.sh`:

    #!/usr/bin/env bash
    #---------------------------#
    # Ajanke BasHTTPd Webserver |
    #----------------------------------------------------------------------
    #
    #  tcpserver -c 10 127.0.0.1 5250 ./bashttpd.sh
    #  socat TCP4-LISTEN:5250,fork EXEC:./bashttpd.sh
    #  netcat -l -p 5250 -e ./bashttpd.sh & #Set LOG=0 in script for netcat
    #
    #  A janky HTTP server written in Bash.

The example commands a the top of the script each starts `bashttpd.sh` and binds it port 5250. Make sure the script is executable first.
After the server is running, you can access the contents of the directory you started it in, from your browser:

    http://127.0.0.1:5250

Note that in the `netcat` example above, the web server will only accept a single connection, then close when the script exits. 
This is only good for testing, and/or serving a single file. If you want the ability to navigate directories...`socat`/`tcpserver`.

Getting started
----------------

  1. Download/copy `bashttpd.sh` and either `tcpserver` or `socat` (if you don't already have one). `netcat` can be used to demo it.
  
      If you're on MacOSX, the `tcpserver` binary/command is available via the `homebrew` package manager;
      the package name is `ucspi-tcp`; meanwhile, `netcat` should already be on your system. `socat` might be too.
      
      If you are installing on RHEL or Debian, the `ucspi-tcp` package is available via EPEL and the base repos, respectively.

      Check for `netcat` with:
      
          which netcat

      Make sure it has the "-e" (execute) flag:

          netcat -help
          
      Install `tcpserver` and/or `socat` on MacOSX with:
      
          brew update
          brew install ucspi-tcp
          brew install socat
          
  2. Make sure you have Bash v3 or higher. If not, install via your package manager.
  
      Check your `bash` version like this:
        
          bash --version
          
  3. Make sure the script is executable. May vary by unices, this works on most:
  
          chmod 664 ./bashttpd
  
  4. Run bashttpd using your TCP server of choice:
  
          tcpserver 127.0.0.1 8080 ./bashttpd.sh

      OR 

          socat TCP4-LISTEN:5250,fork EXEC:./bashttpd.sh

      OR         
      
          netcat -lp 8080 -e ./bashttpd.sh
  
  5. Test it in your browser or with curl by visiting the local URL
  
          http://127.0.0.1:5250

      You should see the contents of that directory.
      
Features
---------

  1. Shows directory listings
  2. Renders plain text, HTML, CSS, and Javascript
  3. Renders image files and downloads other files

Limitations
------------

  1. Does not support authentication, but HTTPS can be done with `socat` and `openssl`
  2. Only supports certain types of HTTP requests, (No POST, just GET & HEAD).

Security
--------

  1. Do not use this in a public-facing environment.
  2. Do not use this in a production environment.
  3. The script rejects POST requests.
  4. Injection is always a threat, even though URI cleaning is performed.

HTTP protocol support
---------------------

  - 404: Returned when requested file/directory not found or inaccessible.
  - 403: Returned when a file is inaccessible to the user that ran the script.
  - 400: Returned when the first word of the first HTTP request line is not `GET` or `HEAD`.
  - 200: Returned with valid content.

As always, your patches/pull requests are welcome!

Testimonials
------------

*"If anyone installs that anywhere, they might meet a gruesome end with a rusty fork"*

  ***--- avleen, BasHTTPd Creator***

*"What is that? Wait a server written in bash. What an abomination!"*

  ***--- anonymous "fan"***
