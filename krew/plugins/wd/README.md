# Kubectl Wait for Deployment Krew Plugin

## Available Optional Parameters:
```
  -n | --namespace   If this is not informed, the default namespace from current context you be used, if it's empty, then default namespace will be used.

  -d | --deployments Deployment or Deployment list with comma separated. You could use it more than one time, for example: kwd -n dev -d nginx -d myapp

  -a | --attempts    Number of times that the check will be executed. Default is 90.

  -i | --interval    Interval in seconds until the next attempt. Default is 5 seconds.
```

## USAGE:
```
  kubectl wd \
    --namespace dev \
    --deployments nginx \
    --attempts 30 \
    --interval 3 \
```
