#!/bin/bash
#1.sudo gem install fastlane
#2.brew install xctool

#计时
SECONDS=0

#假设脚本放置在与项目相同的路径下
project_path=$(pwd)
#取当前时间字符串添加到文件结尾
now=$(date +"%Y_%m_%d_%H_%M_%S")

#指定项目的scheme名称
scheme="GLPaint"
#指定要打包的配置名
configuration="ADHoc"
#指定打包所使用的输出方式，目前支持app-store, package, ad-hoc, enterprise, development, 和developer-id，即xcodebuild的method参数
export_method='development'

#指定项目地址
workspace_path="$project_path/GLPaint.xcworkspace"
#指定输出路径
output_path="$project_path"
#指定输出归档文件地址
archive_path="$output_path/${scheme}_${now}_${configuration}.xcarchive"
#指定输出ipa地址
ipa_path="$output_path/${scheme}_${now}_${configuration}.ipa"
#指定输出ipa名称
ipa_name="${scheme}_${now}_${configuration}.ipa"
#获取执行命令时的commit message
commit_msg="$1"

#fir token (aube:fc20cc22a3bea0627500082028c28c49)
#fir_token="fc20cc22a3bea0627500082028c28c49"

#蒲公英key
uKey="c40b3be13a731517fd443f4907c98a45"
apiKey="aa9dce5e682e79d893819f90d328dc85"

#输出设定的变量值
echo "===workspace path: ${workspace_path}==="
echo "===archive path: ${archive_path}==="
echo "===ipa path: ${ipa_path}==="
echo "===export method: ${export_method}==="
echo "===commit msg: $1==="

#先清空前一次build
fastlane gym --workspace ${workspace_path} --scheme ${scheme} --clean --configuration ${configuration} --archive_path ${archive_path} --export_method ${export_method} --output_directory ${output_path} --output_name ${ipa_name}

#上传到fir
#fir publish ${ipa_path} -T fir_token -c "${commit_msg}"

#输出总用时
echo "===Compile time: ${SECONDS}s==="

#上传到蒲公英
curl -F "file=@${ipa_path}" \
-F "_api_key=${apiKey}" \
-F "buildPassword"="123456" \
-F "buildInstallType"="2" \
http://www.pgyer.com/apiv2/app/upload

#rm -f ${archive_path}
#rm -f ${ipa_path}

open ${output_path}

#输出总用时
echo "===Finished. Total time: ${SECONDS}s==="
