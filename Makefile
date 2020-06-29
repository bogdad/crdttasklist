build-sim:
	xcodebuild \
	-workspace ${project_path}/${project_base_name}.xcworkspace \
	-configuration Debug \
	-scheme ${project_base_name}Debug \
    -sdk iphonesimulator13.5 \
	-destination 'platform=iOS Simulator,name=iPhone 11,OS=13.5' \
    SYMROOT=${project_path}/build/Products/Debug/Sim13.5 OBJROOT=${project_path}/build/sim13.5

build-iphone-release:
	xcodebuild \
	-workspace ${project_path}/${project_base_name}.xcworkspace \
	-configuration Release \
	-scheme ${project_base_name} \
    -sdk iphoneos13.5 \
	-destination 'platform=iOS,name=Vphone' \
    SYMROOT=${project_path}/build/Products/Release/iPhone13.5 OBJROOT=${project_path}/build/iphone13.5

build-iphone-v-release:
	xcodebuild \
	-workspace ${project_path}/${project_base_name}.xcworkspace \
	-configuration Release \
	-scheme ${project_base_name} \
    -sdk iphoneos13.5 \
	-destination 'platform=iOS,name=Varvara’s iPhone' \
    SYMROOT=${project_path}/build/Products/Release/iPhoneV13.5 OBJROOT=${project_path}/build/iPhoneV13.5

build-ipad-release:
	xcodebuild \
	-workspace ${project_path}/${project_base_name}.xcworkspace \
	-configuration Release \
	-scheme ${project_base_name} \
    -sdk iphoneos13.5 \
	-destination 'platform=iOS,name=Varvara’s iPad' \
    SYMROOT=${project_path}/build/Products/Release/iPad13.5 OBJROOT=${project_path}/build/iPad13.5


install-sim: build-sim
	xcrun simctl install 'iPhone 11' ${project_path}/build/Products/Debug/Sim/Debug-iphonesimulator/crdttasklist.app/

run-sim: install-sim
	xcrun simctl launch 'iPhone 11' vs.crdttasklist --console



deploy-iphone: build-iphone-release
	ios-deploy -i 00008020-00130DE93C30003A --justlaunch \
		--bundle ${project_path}/build/Products/Release/iPhone13.5/Release-iphoneos/${project_base_name}.app/

deploy-iphone-v: build-iphone-v-release
	ios-deploy -i 64282f7a7a7e78679e6442fcb3d942a3761bd678 --justlaunch --bundle vs.crdttasklist \
		--bundle ${project_path}/build/Products/Release/iPhoneV13.5/Release-iphoneos/${project_base_name}.app/

deploy-ipad: build-ipad-release
	ios-deploy -i 629d5d7be7c41ec7a85cb26c625c4bd6640e43f6 --justlaunch --bundle vs.crdttasklist\
		--bundle ${project_path}/build/Products/Release/iPad13.5/Release-iphoneos/${project_base_name}.app/	



all: run-sim


.PHONY: all
