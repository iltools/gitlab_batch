#!/usr/bin/env bash
# gitlab右上角头像->偏好设置->访问令牌->勾上对应权限->复制access_token（一旦关闭，就找不到了）
access_token='glpat-XXXXX'
# gitlab地址
domain='http://192.1.0.XXX'
api_prefix='/api/v4'
# projects api：数据如果超过100，那么下面的page要改变, 已改为接口获取
page=1
per_page=50
# 共多少页
total_pages=1
total=0
projects_api="${domain}${api_prefix}/projects?page=${page}&per_page=${per_page}"
# 分组 api
group_project_id=0
group_api="${domain}${api_prefix}/groups?page=${page}&per_page=${per_page}"
group_project_api="${domain}${api_prefix}/groups/${group_project_id}/projects?page=${page}&per_page=${per_page}"
from="project"
# 配置，要可以使用命令8删除以下产生的信息
# 是否写入项目分页信息
isWritePagination=1
isWriteGroupNamePagination=1
# 模拟clone，仅仅创建项目文件夹，创建分组, 创建文件夹
isSimulateClone=0
# 删除合并前的分页信息, 合并信息
isDelPaginationList=0
function reset () {
    page=1
}
function refreshProjectsApi () {
    projects_api="${domain}${api_prefix}/projects?page=${page}&per_page=${per_page}"
}
function refreshGroupNameApi () {
    group_api="${domain}${api_prefix}/groups?page=${page}&per_page=${per_page}"
}
function refreshGroupProjectApi () {
    group_project_api="${domain}${api_prefix}/groups/${group_project_id}/projects?page=${page}&per_page=${per_page}"
}
function pullAllBranch () {
    # 拉取所有分支到本地
    for branch in `git branch -r | grep -v '\->'`; do
        git branch --track "${branch#origin/}" "$branch"
    done
}
function toTrim () {
    # return 只能返回整数
    local str=`echo $1 | awk '{gsub(/^\s+|\s+$/, "");print}'`;
    echo $str
}
function simulateCloneSuccess () {
    # 0 成功
    return $1
}
function eachPagination () {
    # $1-> function
    echo "===============正在遍历每一页Begin================="
    page=1
    for ((i=1; i<=$total_pages; i++)); do
        isLastPage=0
        if [ $i -eq $total_pages ]; then
            isLastPage=1
        else
            isLastPage=0
        fi
        echo $([ "$isLastPage" == 1 ] && echo "---------------------当前遍历第$i页(最后一页)---------------------" || echo "---------------------当前遍历第$i页---------------------")
        $1 $isLastPage $2
        # for ((j=1; j<=$per_page; j++)); do
        # echo "第$i页, 当前第$j个记录";
        # done
        if [ $isLastPage -eq 1 ]; then
            if [ $isDelPaginationList -eq 1 ]; then
                rm -f getProjects.json
            fi
        fi
        page=$[$i+1]
    done
    echo "===============正在遍历每一页End================="
}
function getTotalPage () {
    echo "===============获取项目分页信息Begin================="
    api=''
    if [ "$from" == "project" ]; then
        refreshProjectsApi
        api=$projects_api
    else
        refreshGroupProjectApi
        api=$group_project_api
    fi
    total_pages=$(curl -I --header "PRIVATE-TOKEN: $privateToken" $api | awk -v FS=": " '/^X-Total-Pages/{print $2}')
    total=$(curl -I --header "PRIVATE-TOKEN: $privateToken" $api | awk -v FS=": " '/^X-Total/{print $2}')
    echo "项目总页数：$total_pages,总记录：$total"
    # 写入分页信息
    if [ $isWritePagination -eq 1 ]; then
        curl -sI --header "PRIVATE-TOKEN: $privateToken" $api -o pagination.txt;
    fi
    echo "===============获取项目分页信息End================="
    eachPagination getProjects
}

# 下载所有项目到当前文件夹
function cloneAllProjects() {
    # $1-> 是否最后一页
    if [ "$from" == "project" ]; then
        refreshProjectsApi
        projectList=$(curl -H "PRIVATE-TOKEN: $privateToken" $projects_api)
    else
        refreshGroupProjectApi
        projectList=$(curl -H "PRIVATE-TOKEN: $privateToken" $group_project_api)
    fi
    # 下面如果可以拿到数组的中的http_url_to_repo的话
    # -r去掉", 不然出错
    urlList=(`echo $projectList | jq -r .[].http_url_to_repo`)
    pathList=(`echo $projectList | jq -r .[].path`)
    # 测试：静态写死
    # urlList=(
    #     "http://192.1.0.XXX/XXXX.git",
    #     "http://192.1.0.XXX/XXXX.git"
    # )
    echo "------------共【${#urlList[@]}】个项目------------"
    # 注意这里是包含shared_with_groups数据，但是gitlab统计项目数量是不统计的
    # 数组格式为(A B C)
    for((j=0;j<${#urlList[@]};j++))
    do
        echo "准备克隆第【$[$j+1]】个项目：${urlList[j]}";
        local name=$(toTrim ${pathList[j]})
        if [ $isSimulateClone -eq 0 ]; then 
            git clone ${urlList[j]};
        else
            # 模拟成功
            mkdir "$name"
            simulateCloneSuccess 0
        fi
        if [ $? -eq 0 ]; then
            echo "Clone Success: ${urlList[j]}"
            # 拉取所有分支到本地, jq -r 返回的会带\r所以要去掉
            cd "$name";
            pullAllBranch
            cd ..
        else
            echo "Clone Fail: ${urlList[j]}"
        fi
    done;
}
function updateProjects() {
    # 遍历当前目录下的所有文件和文件夹
    existProject=0
    for item in ./*; do
    # 如果当前项是一个目录，并且该目录下有一个 .git 文件或文件夹（是一个 git 仓库）
    if [ -d "$item" ] && [ -d "$item/.git" ]; then
        # 进入该目录
        existProject=$[$existProject+1]
        echo "正在更新第【$existProject】个项目：【$item】"
        cd "$item"
        # 删除未跟踪的文件和目录以及未跟踪的目录
        git clean -fd
        # 批量更新分支到本地
        git fetch --all
        # 删除远程不存在的分支
        git fetch --prune
        git branch -r
        pullAllBranch
        for branch in `git branch -r | grep -v '\->'`; do
            # origin/main字符串切换成main
            git checkout "${branch##*origin/}"
            # 远程覆盖到本地
            git rebase "$branch"
        done
        # 另外一种拉取远程到本地
        # git branch -r | awk -F/ '{ system("git checkout " $NF) }'
        # 切回到原始目录，以便处理下一个仓库
        cd ..
    fi
    done
}

function mergeFiles () {
    # 分组名/项目合并
    echo "$1"
    for ((i=1; i<=$total_pages; i++)); do
        file=$(cat $2$i.txt)
        if [ $i -eq 1 ]; then
            echo $file > $2.txt
        else
            echo -e "$file" >> $2.txt
        fi
    done
    groupFile=$(cat $2.txt)
    groupFileJson=$(echo $groupFile | jq -s 'reduce .[] as $x ([]; . + $x)')
    # ↓↓↓↓↓↓格式化一下，不然解析不了↓↓↓↓↓↓
    $(echo $groupFileJson | jq -c  > $2.json)
    # 删除下载的分页信息
    if [ $isDelPaginationList -eq 1 ]; then
        echo "删除下载的分页内容"
        for ((i=1; i<=$total_pages; i++)); do
            rm -f $2$i.txt
            rm -f $2.txt
        done
    fi
}
# 查看所有项目
function getProjects() {
    # $1 是否最后一页
    echo "===============获取每一页项目信息Begin================="
    projectList=''
    apiName=$projects_api
    if [ "$from" == "project" ]; then
        refreshProjectsApi
        projectList=$(curl -H "PRIVATE-TOKEN: $privateToken" $projects_api)
        apiName=$projects_api
    else
        refreshGroupProjectApi
        projectList=$(curl -H "PRIVATE-TOKEN: $privateToken" $group_project_api)
        apiName=$group_project_api
    fi
    # 下载到本地
    curl --header "PRIVATE-TOKEN: $privateToken" $apiName -o getProjects$page.txt;
    if [ $1 -eq 1 ]; then
        mergeFiles '正在合并项目文件...' 'getProjects'
    fi
    echo "===============获取每一页项目信息End================="
}

function getGroupNameTotalPage() {
    total_pages=$(curl -I --header "PRIVATE-TOKEN: $privateToken" $group_api | awk -v FS=": " '/^X-Total-Pages/{print $2}')
    total=$(curl -I --header "PRIVATE-TOKEN: $privateToken" $group_api | awk -v FS=": " '/^X-Total/{print $2}')
    echo "分组总页数：$total_pages,总记录：$total"
     # 写入分组分页信息
    if [ $isWriteGroupNamePagination -eq 1 ];then
        curl -sI --header "PRIVATE-TOKEN: $privateToken" $group_api -o groupPagination.txt;
    fi
}
function getGroupName () {
    refreshGroupNameApi
    # 下载到本地
    curl --header "PRIVATE-TOKEN: $privateToken" $group_api -o getGroup$page.txt;
    # 最后一页
    if [ $1 -eq 1 ]; then
        mergeFiles '正在合并分组名文件...' 'getGroup'
    fi
}
function groupNamesCreate() {
    if [ -d "$1" ]; then
        echo "文件夹已经存在"
    else
        mkdir "$1"
    fi
    group_project_id="$3"
    echo -e "创建第$2组;组名:$1;ID:$group_project_id";
    # cd $1 在名字有空格，会出现错误，所以用""
    cd "$1"
    reset
    from="group"
    # 写入分页信息
    getTotalPage
    # 写入分页信息
    eachPagination cloneAllProjects
    cd ..
}
function cloneGroup() {
    groupNameList=$(cat getGroup.json)
    len=(`echo $groupNameList | jq -r length`)
    names=(`echo $groupNameList | jq -r .[].name`)
    # echo $groupNameList | jq -r .[].name > getGroupNames.txt
    ids=(`echo $groupNameList | jq -r .[].id`)
    # echo $groupNameList | jq -r .[].id > getGroupIds.txt
    echo "------------共【$len】组------------"
    local groupIndex=-1
    # 第一种遍历方法
    jq -r '.[].name' getGroup.json | while read line; do
        groupIndex=$[$groupIndex+1]
        groupLastIndex=$[$len-1]
        # 去除 \r
        local name=$(toTrim $line)
        local id=$(toTrim ${ids[groupIndex]})
        groupNamesCreate "$name" $groupIndex "$id"
    done
    if [ $isDelPaginationList -eq 1 ]; then
        rm -f getGroup.json
    fi
    # 第二种遍历方法
    # for line in $(cat getGroupNames.txt)
    # do
    #     echo "${line}"
    # done
    # BUG：${#names[@]} 当名字有空格的时候，获取的长度不对，同时遍历下标得到的结果结果也不一样， 所以用jq的length
    # ↓↓↓↓↓↓↓↓↓↓
    # for((i=0;i<${#names[@]};i++))
    # do
    #     echo "创建第【$[$i+1]】组：${names[i]}";
    # done;
    # ↑↑↑↑↑↑↑↑↑↑
}
function updateGroupProject () {
    jq -r '.[].name' getGroup.json | while read line; do
        # 去除 \r
        local name=$(toTrim $line)
        cd "$name"
        updateProjects
        cd ..
    done
}
function genGroupPagination() {
    from="group"
    getGroupNameTotalPage
    eachPagination getGroupName
}
function removeDownInfo () {
    find ./ -type f -name 'getGroup*' -delete
    find ./ -type f -name 'getProject*' -delete
    find ./ -type f -name '*agination.txt' -delete
}
# 选择令牌方式
while true
do
   #Individual group List
echo -e "请选择令牌获取方式\n读取配置文件的access_token,请输入1\n在命令行输入令牌,请输入2"
read  putKey
        if [ $putKey = "1" ]; then
            echo '您选择了配置文件的access_token'
            privateToken=$access_token
            break
            elif [ $putKey = "2" ]; then
            echo '你选择了在命令行输入令牌，请输入，然后按enter'
            read  privateToken
            break
            else
            echo "请输入正确的指令"
        fi

done

echo 令牌为：$privateToken
reset () {
    page=1
}
# 交互式命令
while true
do
reset
echo -e "clone所有项目,请输入1\n同步所有分支到本地,请输入2\n获取所有项目,请输入3\n查看分组,请输入4\n按组clone,请输入5\n按组同步所有分支到本地,请输入6\n查看当前目录文件大小,请输入7\n清除因clone下载存储到本地的内容,请输入8\n回到开始状态,请输入9"
read  putKey
    if [ $putKey = "1" ]; then
        from="project"
        getTotalPage
        eachPagination cloneAllProjects
        break
        elif [ $putKey = "2" ]; then
        from="project"
        updateProjects
        break
        elif [ $putKey = "3" ]; then
        from="project"
        getTotalPage
        break
        elif [ $putKey = "4" ]; then
        genGroupPagination
        break
        elif [ $putKey = "5" ]; then
        genGroupPagination
        cloneGroup
        break
        elif [ $putKey = "6" ]; then
        genGroupPagination
        updateGroupProject
        break
        elif [ $putKey = "7" ]; then
        # 查看各项目大小
        du -h --max-depth=1
        break
        elif [ $putKey = "8" ]; then
        # 删除所有下载信息
        echo '以下是将会删除的文件'
        find ./ -type f -name 'getGroup*'
        find ./ -type f -name 'getProject*'
        find ./ -type f -name '*agination.txt'
        removeDownInfo
        break
        elif [ $putKey = "9" ]; then
        echo '清除测试文件夹，下载信息'
        for item in ./*; do
        if [ -d "$item" ]; then
            rm -rf $item
        fi
        done
        removeDownInfo
        break
        else
        echo "请输入正确的指令"
    fi
done