# 目的

> 按组/项目一键clone所有代码，不用每个去下载，更新也是如此！

# 准备

## [git](https://git-scm.com/downloads/win)

## [jq](https://github.com/jqlang/jq), 需要放在mingw64/bin/里面

## gitlab token

> gitlab右上角头像->偏好设置->访问令牌->勾上对应权限->复制access_token（一旦关闭，就找不到了）

# 功能

> 通过接口获取所有项目/组下所有项目分页，实现以下功能

- 按项目下载
- 按项目更新所有远程分支到本地
- 按组下载
- 按组项目更新所有远程分支到本地

# 使用

把gitlab_batch.sh放到需要下载的文件夹，右键Git Bash Here, 使用以下命令运行, 然后根据提示输入对应的数字

```bash
sh gitlab_batch.sh
```

# 测试

- window 11 22621.963
- 其他自行测试
  

# 可能出现的报错

## RPC failed; curl 18 transfer closed with outstanding read data remaining

```
Cloning into 'abc-web'...
remote: Enumerating objects: 15010, done.
remote: Counting objects: 100% (2087/2087), done.
remote: Compressing objects: 100% (1549/1549), done.
error: RPC failed; curl 18 transfer closed with outstanding read data remaining
fatal: the remote end hung up unexpectedly
fatal: early EOF
fatal: index-pack failed
```