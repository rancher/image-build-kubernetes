# rancher/hardened-kubernetes

## Build
Build hardened kubernetes needs to include the rke2 release version and the build meta to work properly. Just running
`make` will hardcode `v1.32.2-rke2dev-build<todaysdate>`. If you want to set your own versions for testing and when 
pushing a tag to the repo to make a release you will want to add the full version of kubernetes rke2 release and
the build meta like the following.

```sh
TAG=v1.32.2-rke2r1-build$(TZ=UTC date +%Y%m%d) make
```

## Pushing a Release
You will need to know the RKE2 version you are releasing before you can build hardened kubernetes. For example a current
release is `v1.32.2+rke2r1` and this translates to a hardened kubernetes build tag of `v1.32.2-rke2r1-build<date Ymd>`. 
Let this project build and release images and set your version in the [dockerfile](https://github.com/rancher/rke2/blob/master/Dockerfile)
