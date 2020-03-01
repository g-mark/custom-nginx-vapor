# test-nginx-vapor
Example of putting NGiNx in front of Vapor on Heroku

There are two requests handled by NGiNx:

```
/index.html
/other.html
```

There are two Vapor routes:

```
/
/hello/:string
```

The setup of this branch is that NGiNx will try for a static file and deliver that.  If it can't find a static file, it will pass the request on to Vapor.  This means that all 404 errors are handled by Vapor.

#### Heroku setup

1. Create an app
2. Add official ngnix buildback, I used:  
   [Heroku Buildpack: NGINX](https://elements.heroku.com/buildpacks/heroku/heroku-buildpack-nginx)  
   `heroku-community/nginx` (or https://github.com/heroku/heroku-buildpack-nginx.git)
3. Add official Vapor buildpack - I used:  
   [Heroku buildpack: swift](https://elements.heroku.com/buildpacks/vapor-community/heroku-buildpack)  
   `vapor/vapor`
4. Grab the app's git URL.  (in `Settings`, something like `https://git.heroku.com/YOUR-APP-NAME-HERE.git`)
5. Fork this repo, clone it locally
6. Add your app's git URL as an origin for you local repo
7. Push the repo to the Heroku origin.
   This will deploy the app.

#### How it works

When code is pushed to the app's git repo, Heroku will run a post_receive hook that triggers each of the buildpacks added to the app, in the order that they are listed in your `Settings` pane.  This also happes to be the same order that they were added in the above steps: `ngnix` then `vapor`.

Once both buildpacks have finished building, the `Procfile` is executed.

The `Procfile` in this repo has a single line, that runs two commands:
```
web: bin/start-nginx Run serve --env production --port 8080 --hostname 0.0.0.0
```

- `bin/start-nginx` starts ngnix
- `Run serve --env production --port 8080 --hostname 0.0.0.0` runs the vapor app.

When ngnix is built, it uses the config file at `config/nginx.conf.erb` as the primary configuration for the ngnix server.  Towards the bottom of the file is where you'll find the magic sauce:

```
   root /app/Public;
   
   # Serve all public/static files via nginx and then fallback to Vapor for the rest
   try_files $uri @proxy;
   
   location @proxy {
      proxy_pass http://127.0.0.1:8080;
      proxy_pass_header Server;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_connect_timeout 3s;
      proxy_read_timeout 10s;
      proxy_redirect off;
   }
```

So, when a URL is requested, ngnix will see if there's a file it can deliver from the `Public` directory (everything in the git repo is installed at `/app`, so the `root /app/Public` directive in the config file points to our `Public` directory as the root of the web server).  If it can't find a file, it'll pas the URL on to the Vapor app.

NGiNx listens on the normal http port (80), and when needed, proxies the requests on to port 8080, where the Vapor app is listening.
