# custom-nginx-vapor
Example of putting NGiNx in front of Vapor on Heroku - kind of like [test-nginx-vapor](https://github.com/g-mark/test-nginx-vapor), but a little more advanced.  Note: this was built with Vapor 3.  Probably only the custom middleware would need to be updated for Vapor 4.  This repo is mostly about standing up NGiNx in front of Vapor on Heroku.

This setup only proxies specific routes to Vapor, and the rest are delivered as static files or a 404.

There are four Vapor routes:

| path | content                      |
| ---- | ---------------------------- |
| /    | standard "it works!" message |
| /hello/:string | Says "hello, :string" |
| /hi | causes a 404 from within Vapor, delivering the same file as nginx<br>(nginx has a `/hi` location, but the vapor app doesn't have a `/hi` route) |
| /crash/:string | causes an internal server error from Vapor<br>(nginx has a `/crash/*` location, and the vapor app tries to parse the extra path component as an int) |


There are two requests handled by NGiNx (well, in addition to all the "assets"):

```
/index.html
/other.html
```



### HTTPS

All requests are forced to https, with this goodie in the `nginx.conf.erb`config file:

```
# Force http requests to be https
if ($http_x_forwarded_proto != "https") {
    return 301 https://$host$request_uri;
}
```



### HTTP Errors

Any 404 errors that happen deliver the `/Public/404.html` file.  404 errors can be caught by NGiNx _or_ Vapor. The NGiNx 404 error handling is specified in the `nginx.conf.erb`config file:

```
# custom error page
error_page 404 /404.html;
location = /404.html {
    internal;
}
```

404 errors that happen inside of Vapor are handled using a custom middleware which delivers the same `/Public/404.html` file.  The default in Vapor is to return all errors in a JSON format.  If you're using Leaf as a templating engine, you can also set Leaf up to deliver a custom html error page.  I wrote a custom middleware so that I could use the _exact same file_ for 404s caught be either service.

This middleware is in `HTMLErrorMiddleware.swift`, and is pretty easy to configure, as it supports http status ranges:

```swift
var middlewares = MiddlewareConfig()

middlewares.use(
    HTMLErrorMiddleware(
        .public(file: "404.html", for: 404),		 // use /Public/404.html for all 404 errors
        .resource(file: "5xx.html", for: 500...) // use /Resources/5xx.html for all >= 500
    )
)

services.register(middlewares)
```

I kind of threw it together, so there's certainly room for improvement.  For example, if no file has been specified for a specific status code, the middleware will just send some plan text.



## Try it live

It's on a free heroku plan, so if no requests have been made in a little while, it might take a second to warm up:

https://custom-nginx-vapor.herokuapp.com/



## Setup

#### Heroku setup

1. Create an app
2. Add my fancy custom buildback, a fork of the Heroku official NGiNx buildpack:  
   [heroku-buildpack-nginx-vapor](https://github.com/g-mark/heroku-buildpack-nginx-vapor)  
   `https://github.com/g-mark/heroku-buildpack-nginx-vapor`  
   Why a custom buildpack?  I wanted one that was built to work with Vapor out of the box.
3. Add official Vapor buildpack - I used:  
   [Heroku buildpack: swift](https://elements.heroku.com/buildpacks/vapor-community/heroku-buildpack)  
   `vapor/vapor`
4. Grab the app's git URL.  (in `Settings`, something like `https://git.heroku.com/YOUR-APP-NAME-HERE.git`)
5. Fork this repo, clone it locally
6. Add your app's git URL as an origin for you local repo
7. Push the repo to the Heroku origin.
   This will deploy the app.

#### How it works

When code is pushed to the app's git repo, Heroku will run a post_receive hook that triggers each of the buildpacks added to the app, in the order that they are listed in your `Settings` pane.  This also happens to be the same order that they were added in the above steps: `ngnix` then `vapor`.

Once both buildpacks have finished building, the `Procfile` is executed.

The `Procfile` in this repo has a single line, that runs two commands:
```
web: bin/start-nginx Run serve --env production --port 8080 --hostname 0.0.0.0
```

- `bin/start-nginx` starts ngnix
- `Run serve --env production --port 8080 --hostname 0.0.0.0` runs the vapor app.

When ngnix is built, it uses the config file at `config/nginx.conf.erb` as the primary configuration for the ngnix server.  This contains the core routing needed to have NGiNx stand as a proxy in front of Vapor.  In my other repo - [test-nginx-vapor](https://github.com/g-mark/test-nginx-vapor) - the setup is much simpler.  This one works under the notion that you want NGiNx to do most of the basic http work like serving static files, forcing https, and serving error pages.  To support this notion there is a single config file that has the common (most likely _all_) of the reverse proxy config - `vapor_proxy.conf.erb` - and the main NGiNx config will include that as needed.

Here's what I mean:

```
# custom exact location (`/` - welcome)
location = / {
    include vapor_proxy.conf;
}

# custom prefix location (`/hello/*` - all hello routes)
location /hello/ {
    include vapor_proxy.conf;
}

# custom exact location (`/hi` - forces a 404 from vapor)
location = /hi {
    include vapor_proxy.conf;
}

# custom prefix location (`/crash/*` - forces an internal error)
location /crash/ {
    include vapor_proxy.conf;
}
```


