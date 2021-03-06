# C++ Compiler
CC=g++ -std=c++14
NCC=nvcc -std=c++11

# Using for clearer error finding
BONUS=2>&1 | grep -E --color=always 'error|warning|$$'

BASE_C_FLAG=`pkg-config --cflags opencv gstreamer-1.0 `
BASE_LD_FLAG=`pkg-config --libs opencv  gstreamer-1.0 ` -L/usr/local/cuda-7.5/lib64

CFLAGS=$(BASE_C_FLAG)
CFLAGS+=-Wall -O3 -fopenmp
LDFLAGS=$(BASE_LD_FLAG)
LDFLAGS+=-lboost_system -lboost_timer -lgomp -lglut -lGL -lGLEW -lGLU -lboost_serialization -lcuda -lcudart -L$(LIB) -lfftw3 -lfftw3_omp -lm

# Paths
SRC=src/core/src
LIB=lib
OBJ=obj
DATA=data/Cut15
EXP=data/modexp
SRC_FILES = $(wildcard $(SRC)/*.cpp)
CUDA_FILES = $(wildcard $(SRC)/Cuda/*.cu)
KLT_FILES = $(wildcard $(SRC)/KLT/*.cpp)
CONFIG_FILES = $(wildcard $(DATA)/*.config)
RECORD_FILES = $(wildcard $(EXP)/*/*.txt)
DEPD = $(wildcard $(SRC)/header/.h)
BIN=bin
TMP=tmp
INC=-I/usr/local/cuda-7.5/extras/CUPTI/include -I$(SRC) -I/usr/local/cuda-7.5/targets/x86_64-linux/include/ -I$(SRC)/fftw++-2.02

# All files
OBJ_FILES := $(addprefix obj/,$(notdir $(SRC_FILES:.cpp=.o)))
OBJ_KLT_FILES := $(addprefix obj/KLT/,$(notdir $(KLT_FILES:.cpp=.o)))
OBJ_CUDA_FILES := $(addprefix obj/Cuda/,$(notdir $(CUDA_FILES:.cu=.o)))

# Used for debug
cccyan=$(shell echo "\033[0;36m")
ccend=$(shell echo "\033[0m")

all: VideoStitch

test:
	$(CC) $(CFLAGS) $? -I. -I$(SRC)/fftw++-2.02 tools/SaliencyMapExtractor/QFFT.cpp $(SRC)/fftw++-2.02/fftw++.cc -o $(BIN)/$@ $(LDFLAGS)

testrun:
	bin/test

tools: VideoStitch CameraCalibrator ImagesDumper

BUILD_PRINT = \e[1;34mBuilding $<\e[0m

debug:
	objdump -d $(BIN)/VideoStitch > dump

makeObj: $(OBJ_FILES)
	@echo "$(cccyan)[Obj files generated]$(ccend)"

$(OBJ)/%.o: $(SRC)/%.cpp $(SRC)/header/%.h
	@mkdir -p $(OBJ)
	@echo "$(cccyan)[Run OBJ $@ compile]$(ccend)"	
	$(CC) $(CFLAGS) $(INC) -c -o $@ $< 
	
$(OBJ)/KLT/%.o: $(SRC)/KLT/%.cpp $(SRC)/KLT/%.h
	@mkdir -p $(OBJ)
	@mkdir -p $(OBJ)/KLT
	@echo "$(cccyan)[Run OBJ $@ compile]$(ccend)"	
	$(CC) $(CFLAGS) $(INC) -c -o $@ $< 	

$(OBJ)/Cuda/%.o: $(SRC)/Cuda/%.cu $(SRC)/Cuda/%.h
	@mkdir -p $(OBJ)
	@mkdir -p $(OBJ)/Cuda
	@echo "$(cccyan)[Run OBJ $@ compile]$(ccend)"	
	$(NCC) $(INC) -c -o $@ $< 

VideoStitch: $(OBJ_FILES) $(OBJ_KLT_FILES) $(OBJ_CUDA_FILES)
	@echo "$(cccyan)[Run Link compile]$(ccend)"
	$(CC) $? $(CFLAGS) -I$(SRC) -I$(SRC)/fftw++-2.02 src/cmd/main.cpp  $(SRC)/fftw++-2.02/fftw++.cc -o $(BIN)/$@ $(LDFLAGS) 

calcFPS:
	@for CONFIG in $(CONFIG_FILES); do \
		for RECORD in Record1.txt Record2.txt Record3.txt Record4.txt Record5.txt Record6.txt Record7.txt Record8.txt Record9.txt Record10.txt ; do \
			TMP=$${CONFIG##*/}; \
			TMP2=$${RECORD##*/}; \
			sh scripts/calcFPS.sh $$TMP $$TMP2; \
		done \
	done

SaliencyMapExtractor:
	$(CC) $(CFLAGS) $? -I. tools/SaliencyMapExtractor/SaliencyMapExtractor.cpp -o $(BIN)/$@ $(LDFLAGS)

runSME:
	$(BIN)/SaliencyMapExtractor BinWangApr2014 results/pano_960_480.avi 

socket: $(OBJ_FILES) 
	$(CC) $? -I$(SRC) -I. src/cardboard/VSSocket.cpp src/cardboard/server.cpp -o $(BIN)/$@ $(LDFLAGS)

socketC:
	$(CC) obj/Usage.o $? -I$(SRC) src/cardboard/client.cpp -o $(BIN)/$@ $(LDFLAGS)

bauzi: 
	$(CC) obj/Usage.o $? -I$(SRC) -Itools/BauziCalibration tools/BauziCalibration/BauziCalibrator.cpp -o $(BIN)/$@ $(LDFLAGS)

featureGenerator: 
	$(CC) obj/Usage.o $? -I$(SRC) -Itools/ManualFeatureGenerator tools/BauziCalibration/ManualFeatureGenerator.cpp -o $(BIN)/$@ $(LDFLAGS)

PR: $(OBJ_FILES)
	@echo "$(cccyan)[Run Link compile]$(ccend)"
	$(CC) $? -I$(SRC) src/opengl/PartialRenderGUI.cpp -o $(BIN)/$@ $(LDFLAGS)

CameraCalibrator:
	@echo "$(cccyan)[Ganerate camera calibrator]$(ccend)"
	$(CC) -o $(BIN)/$@ tools/calibration/CameraCalibrator.cpp $(LDFLAGS)

ImagesDumper:
	@echo "$(cccyan)[Ganerate images dumper]$(ccend)"
	$(CC) -I$(SRC) obj/Usage.o -o $(BIN)/$@ tools/imagesDumper/ImagesDumper.cpp $(LDFLAGS)

final:
	$(BIN)/VideoStitch --input data/Cut15/inputVideo.txt --calibration $(DATA)/Calibration.txt --pto $(DATA)/15.pto --duration 1500 --output Final_15_ --featureInfo $(DATA)/FeatureInfo.txt --saliency $(DATA)/saliency.mp4 --config $(DATA)/../my.config --sensorData $(DATA)/../modexp/若曦/Record1.txt
	$(BIN)/VideoStitch --input data/Cut17/inputVideo.txt --calibration $(DATA)/Calibration.txt --pto $(DATA)/15.pto --duration 1000 --output Final_17_ --featureInfo $(DATA)/FeatureInfo.txt --saliency $(DATA)/saliency.mp4 --config $(DATA)/../my.config --sensorData $(DATA)/../modexp/若曦/Record1.txt

birthday:
	for RECORD in $(RECORD_FILES); do \
		for CONFIG in $(CONFIG_FILES); do \
			echo "bin/VideoStitch --input data/Cut15/inputVideo.txt --calibration $(DATA)/Calibration.txt --pto data/Cut15/15.pto --duration 150 --output StitchResult.avi --featureInfo data/Cut15/FeatureInfo.txt --saliency data/Cut15/saliency.mp4 --config $$CONFIG --sensorData $$RECORD"; \
			bin/VideoStitch --input data/Cut15/inputVideo.txt --calibration $(DATA)/Calibration.txt --pto data/Cut15/15.pto --duration 150 --output StitchResult.avi --featureInfo data/Cut15/FeatureInfo.txt --saliency data/Cut15/saliency.mp4 --config $$CONFIG --sensorData $$RECORD; \
		done \
	done

	for RECORD in $(RECORD_FILES); do \
		for CONFIG in $(CONFIG_FILES); do \
			echo "bin/VideoStitch --input data/Cut17/inputVideo.txt --calibration $(DATA)/Calibration.txt --pto data/Cut15/15.pto --duration 100 --output StitchResult.avi --featureInfo data/Cut15/FeatureInfo.txt --saliency data/Cut15/saliency.mp4 --config $$CONFIG --sensorData $$RECORD"; \
			bin/VideoStitch --input data/Cut17/inputVideo.txt --calibration $(DATA)/Calibration.txt --pto data/Cut15/15.pto --duration 100 --output StitchResult.avi --featureInfo data/Cut15/FeatureInfo.txt --saliency data/Cut15/saliency.mp4 --config $$CONFIG --sensorData $$RECORD; \
		done \
	done

run:
	@mkdir -p $(TMP)
	#$(BIN)/VideoStitch --input data/gopro/inputVideo.txt --calibration data/MultiCalibration/calibrationResult.txt --pto data/Cut15/15.pto --duration 100 --output StitchResult.avi
	#$(BIN)/VideoStitch --input data/MultiCalibration/inputVideo.txt --calibration data/MultiCalibration/calibrationResult.txt --pto data/Cut15/15.pto --duration 100 --output StitchResult.avi
	#$(BIN)/VideoStitch --input data/2016-05-04/test01/inputVideo.txt --calibration $(DATA)/Calibration.txt --pto $(DATA)/15.pto --duration 100 --output StitchResult.avi --featureInfo $(DATA)/FeatureInfo.txt --saliency $(DATA)/saliency.mp4 --config $(DATA)/my.config
	$(BIN)/VideoStitch --input data/Cut15/inputVideo.txt --calibration $(DATA)/Calibration.txt --pto $(DATA)/15.pto --duration 100 --output StitchResult.avi --featureInfo $(DATA)/FeatureInfo.txt --saliency $(DATA)/saliency.mp4 --config $(DATA)/../my.config --sensorData $(DATA)/../modexp/順堯/Record1.txt

runPR:
	$(BIN)/PR --input data/Cut15/inputVideo.txt --calibration data/Cut15/Calibration.txt --pto data/Cut15/15.pto --duration 300 --output StitchResult.avi

runBauzi:
	$(BIN)/bauzi --input data/Bauzi/inputImage.txt --iter 10 --featureInfo FeatureInfo.txt

runFeatureGenerator:
	$(BIN)/featureGenerator --input data/Cut15/inputImage.txt --featureInfo data/Cut15/FeatureInfo.txt

runSocket:
	$(BIN)/socket --input data/Cut15/inputVideo.txt --calibration data/Cut15/Calibration.txt --pto data/Cut15/15.pto --duration 100 --output StitchResult.avi

calibrator:
	$(BIN)/CameraCalibrator data/CalibrationImages2/input_config.xml

dumper:
	$(BIN)/ImagesDumper data/Cut15/inputVideo.txt data/Library20160216/pattern.png 0 1 1 data/Cut15/raw/
	#$(BIN)/ImagesDumper data/Bauzi/inputVideo.txt data/Library20160216/pattern.png 0 1 1 data/Bauzi/raw/
	#$(BIN)/ImagesDumper data/Library20160216/inputVideo2.txt data/Library20160216/pattern.png 0 1 1 data/Library20160216/dump4
	#$(BIN)/ImagesDumper data/Library20160216/inputVideo2.txt data/Library20160216/pattern.png 0 1 1 data/Library20160216/dump3

clean:
	- rm -r $(BIN)/VideoStitch
	- rm -rf obj/*.o
	- rm -rf tmp/*

CC_FLAGS += -MMD
-include $(OBJFILES:.o=.d)
