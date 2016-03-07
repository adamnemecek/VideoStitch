#include <header/BlendingProcessor.h>BlendingProcessor::BlendingProcessor( int vc, Rect canvasROI ) : mViewCount(vc), mCanvasROI(canvasROI) {	// Calculate blending strength	float blendStrength = 5.f;	float blendWidth = sqrt(static_cast<float>(mCanvasROI.area())) * blendStrength / 100.f;    setSharpness( 1.f/blendWidth );}void BlendingProcessor::genWeightMapByMasks(vector<Mat> masks) {    mWeightMaps.resize(mViewCount);    mDilateMasks.resize(mViewCount);    // Save dilate masks    for (int v=0; v<mViewCount; v++) {        Mat mask_warped = masks[v].clone();        Mat dilated_mask, seam_mask;        dilate(mask_warped, dilated_mask, Mat());        cv::resize(dilated_mask, seam_mask, mask_warped.size());        mask_warped = seam_mask & mask_warped;        mDilateMasks[v] = mask_warped;        UMat weightMap;        cv::detail::createWeightMap(mDilateMasks[v], sharpness_, weightMap);        mWeightMaps[v] = weightMap.getMat(ACCESS_READ).clone();    }    logMsg(LOG_INFO, "Done generating weight map for blending");}void BlendingProcessor::preProcess(Rect dst_roi, vector<Mat> imgs) {    // Prepare    prepare(dst_roi);    // Feed    feeds(imgs);}BlendingProcessor::~BlendingProcessor() {	}void BlendingProcessor::prepare(Rect dst_roi) {    dst_roi_ = dst_roi;    dst_.create(mCanvasROI.size(), CV_16SC3);    dst_.setTo(Scalar::all(0));    dst_mask_.create(dst_.size(), CV_8U);    dst_mask_.setTo(Scalar::all(0));    dst_weight_map_.create(dst_.size(), CV_32F);    dst_weight_map_.setTo(0);}void BlendingProcessor::feeds(vector<Mat> imgs) {    Mat dst = dst_.getMat(ACCESS_RW);    Mat dst_weight_map = dst_weight_map_.getMat(ACCESS_RW);    for (int v=0; v<mViewCount; v++) {        Mat img = imgs[v](dst_roi_);        img.convertTo(img, CV_16SC3);        CV_Assert(img.type() == CV_16SC3);        Mat weight_map = mWeightMaps[v](dst_roi_);                int dx = dst_roi_.x;        int dy = dst_roi_.y;        for (int y = 0; y < img.rows; ++y) {            const Point3_<short>* src_row = img.ptr<Point3_<short> >(y);            Point3_<short>* dst_row = dst.ptr<Point3_<short> >(dy + y);            const float* weight_row = weight_map.ptr<float>(y);            float* dst_weight_row = dst_weight_map.ptr<float>(dy + y);            for (int x = 0; x < img.cols; ++x) {                dst_row[dx + x].x += static_cast<short>(src_row[x].x * weight_row[x]);                dst_row[dx + x].y += static_cast<short>(src_row[x].y * weight_row[x]);                dst_row[dx + x].z += static_cast<short>(src_row[x].z * weight_row[x]);                dst_weight_row[dx + x] += weight_row[x];            }        }        }}void BlendingProcessor::feed (InputArray _img, InputArray weightMap, Point tl) {    // Move to feeds}void BlendingProcessor::blend(InputOutputArray dst, InputOutputArray dst_mask) {    static const float WEIGHT_EPS = 1e-5f;    cv::detail::normalizeUsingWeightMap(dst_weight_map_, dst_);    compare(dst_weight_map_, WEIGHT_EPS, dst_mask_, CMP_GT);    Blender::blend(dst, dst_mask);}