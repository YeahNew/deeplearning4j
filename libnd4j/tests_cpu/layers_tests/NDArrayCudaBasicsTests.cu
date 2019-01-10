/*******************************************************************************
 * Copyright (c) 2015-2018 Skymind, Inc.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ******************************************************************************/

 //
 // @author raver119@gmail.com
 //

#include "testlayers.h"
#include <NDArray.h>
#include <NDArrayFactory.h>
#include <Context.h>
#include <Node.h>
#include <graph/Variable.h>
#include <graph/VariableSpace.h>
#include <graph/LaunchContext.h>
#include <specials_cuda.h>
#include <TAD.h>

#include <cuda.h>
#include <cuda_launch_config.h>

using namespace nd4j;
using namespace nd4j::graph;

class NDArrayCudaBasicsTests : public testing::Test {
public:

};

//////////////////////////////////////////////////////////////////////////
static cudaError_t allocateDeviceMem(LaunchContext& lc, std::vector<void*>& devicePtrs, const std::vector<std::pair<void*,size_t>>& hostData) {

    if(devicePtrs.size() != hostData.size())
        throw std::invalid_argument("prepareDataForCuda: two input sts::vectors should same sizes !");

    cudaError_t cudaResult;

    void* reductionPointer;
    cudaResult = cudaMalloc(reinterpret_cast<void **>(&reductionPointer),  1024*1024);			if(cudaResult != 0) return cudaResult;
    int* allocationPointer;
    cudaResult = cudaMalloc(reinterpret_cast<void **>(&allocationPointer), 1024*1024);			if(cudaResult != 0) return cudaResult;

    lc.setReductionPointer(reductionPointer);
    lc.setAllocationPointer(allocationPointer);
    cudaStream_t stream = *lc.getCudaStream();

    for(int i = 0; i < devicePtrs.size(); ++i) {

        cudaResult = cudaMalloc(reinterpret_cast<void **>(&devicePtrs[i]), hostData[i].second); if(cudaResult != 0) return cudaResult;
        cudaMemcpyAsync(devicePtrs[i], hostData[i].first, hostData[i].second, cudaMemcpyHostToDevice, stream);
    }
    return cudaResult;
}

TEST_F(NDArrayCudaBasicsTests, Test_Registration_1) {
    auto x = NDArrayFactory::create<int>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<int>('c', {5}, {5, 4, 3, 2, 1});

    ASSERT_TRUE(x.isActualOnDeviceSide());
    ASSERT_TRUE(x.isActualOnHostSide());
}

TEST_F(NDArrayCudaBasicsTests, Test_Registration_2) {
    auto x = NDArrayFactory::create<int>('c', {5});
    auto y = NDArrayFactory::create<int>('c', {5});

    ASSERT_TRUE(x.isActualOnDeviceSide());
    ASSERT_FALSE(x.isActualOnHostSide());
}

TEST_F(NDArrayCudaBasicsTests, Test_Registration_3) {
    auto x = NDArrayFactory::create<int>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<int>('c', {5}, {5, 4, 3, 2, 1});

    ASSERT_TRUE(x.isActualOnDeviceSide());
    ASSERT_TRUE(x.isActualOnHostSide());

    NDArray::registerSpecialUse({&x}, {&y});

    ASSERT_TRUE(x.isActualOnDeviceSide());
    ASSERT_FALSE(x.isActualOnHostSide());

    ASSERT_TRUE(y.isActualOnDeviceSide());
    ASSERT_TRUE(y.isActualOnHostSide());
}

TEST_F(NDArrayCudaBasicsTests, Test_Registration_01) {
    auto x = NDArrayFactory::create_<int>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create_<int>('c', {5}, {5, 4, 3, 2, 1});

    ASSERT_TRUE(x->isActualOnDeviceSide());
    ASSERT_TRUE(x->isActualOnHostSide());
    delete x;
    delete y;
}

TEST_F(NDArrayCudaBasicsTests, Test_Registration_02) {
    auto x = NDArrayFactory::create_<int>('c', {5});
    auto y = NDArrayFactory::create_<int>('c', {5});

    ASSERT_TRUE(x->isActualOnDeviceSide());
    ASSERT_FALSE(x->isActualOnHostSide());
    delete x;
    delete y;
}

TEST_F(NDArrayCudaBasicsTests, Test_Registration_03) {
    auto x = NDArrayFactory::create_<int>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create_<int>('c', {5}, {5, 4, 3, 2, 1});

    ASSERT_TRUE(x->isActualOnDeviceSide());
    ASSERT_TRUE(x->isActualOnHostSide());

    NDArray::registerSpecialUse({y}, {x});
    x->applyTransform(transform::Neg, y, nullptr);
    //ASSERT_TRUE(x->isActualOnDeviceSide());
    //ASSERT_FALSE(x->isActualOnHostSide());

    //ASSERT_TRUE(y->isActualOnDeviceSide());
    //ASSERT_TRUE(y->isActualOnHostSide());
    //y->syncToHost();
    y->printBuffer("Negatives");
    delete x;
    delete y;
}

TEST_F(NDArrayCudaBasicsTests, Test_Cosine_1) {
    auto x = NDArrayFactory::create_<double>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create_<double>('c', {5}, {5, 4, 3, 2, 1});

    ASSERT_TRUE(x->isActualOnDeviceSide());
    ASSERT_TRUE(x->isActualOnHostSide());

    NDArray::registerSpecialUse({y}, {x});
    x->applyTransform(transform::Cosine, y, nullptr);
    //ASSERT_TRUE(x->isActualOnDeviceSide());
    //ASSERT_FALSE(x->isActualOnHostSide());

    //ASSERT_TRUE(y->isActualOnDeviceSide());
    //ASSERT_TRUE(y->isActualOnHostSide());
    //y->syncToHost();
    y->printBuffer("Cosine");
    delete x;
    delete y;
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestAdd_1) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto z = NDArrayFactory::create<double>('c', { 5 }, {10, 10, 10, 10, 10});

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 2, 4, 6, 8, 10 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);

    Nd4jPointer nativeStream = (Nd4jPointer)malloc(sizeof(cudaStream_t));
    CHECK_ALLOC(nativeStream, "Failed to allocate memory for new CUDA stream", sizeof(cudaStream_t));
    cudaError_t dZ = cudaStreamCreate(reinterpret_cast<cudaStream_t *>(&nativeStream));
    auto stream = reinterpret_cast<cudaStream_t *>(&nativeStream);

    //cudaMemcpyAsync(devBufferPtrX, x.buffer(), x.lengthOf() * x.sizeOfT(), cudaMemcpyHostToDevice, *stream);
    //cudaMemcpyAsync(devShapePtrX, x.shapeInfo(), shape::shapeInfoByteLength(x.shapeInfo()), cudaMemcpyHostToDevice, *stream);

    LaunchContext lc(stream, nullptr, nullptr);
    NativeOpExecutioner::execPairwiseTransform(&lc, pairwise::Add, x.buffer(), x.shapeInfo(), x.specialBuffer(), x.specialShapeInfo(), y.buffer(), y.shapeInfo(), y.specialBuffer(), y.specialShapeInfo(), z.buffer(), z.shapeInfo(), z.specialBuffer(), z.specialShapeInfo(), nullptr);
    auto res = cudaStreamSynchronize(*stream);
    ASSERT_EQ(0, res);
    //double* localBuffer = ;
    cudaMemcpy(z.buffer(), z.specialBuffer(), z.lengthOf() * z.sizeOfT(), cudaMemcpyDeviceToHost);
    res = cudaStreamSynchronize(*stream);
    ASSERT_EQ(0, res);
    x.printBuffer("X = ");
    y.printBuffer("Y = ");
    z.printBuffer("Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < z.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestAdd_2) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 2, 4, 6, 8, 10 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);

    Nd4jPointer nativeStream = (Nd4jPointer)malloc(sizeof(cudaStream_t));
    CHECK_ALLOC(nativeStream, "Failed to allocate memory for new CUDA stream", sizeof(cudaStream_t));
    cudaError_t dZ = cudaStreamCreate(reinterpret_cast<cudaStream_t *>(&nativeStream));
    auto stream = reinterpret_cast<cudaStream_t *>(&nativeStream);

    //cudaMemcpyAsync(devBufferPtrX, x.buffer(), x.lengthOf() * x.sizeOfT(), cudaMemcpyHostToDevice, *stream);
    //cudaMemcpyAsync(devShapePtrX, x.shapeInfo(), shape::shapeInfoByteLength(x.shapeInfo()), cudaMemcpyHostToDevice, *stream);
    z.lazyAllocateBuffer();
    LaunchContext lc(stream, *stream, nullptr, nullptr);
    NativeOpExecutioner::execPairwiseTransform(&lc, pairwise::Add, nullptr, x.shapeInfo(), x.specialBuffer(), x.specialShapeInfo(), nullptr, y.shapeInfo(), y.specialBuffer(), y.specialShapeInfo(), nullptr, z.shapeInfo(), z.specialBuffer(), z.specialShapeInfo(), nullptr);
    auto res = cudaStreamSynchronize(*stream);
    ASSERT_EQ(0, res);

    cudaMemcpyAsync(z.buffer(), z.specialBuffer(), z.lengthOf() * z.sizeOfT(), cudaMemcpyDeviceToHost, *stream);
    res = cudaStreamSynchronize(*stream);
    ASSERT_EQ(0, res);
    z.printBuffer("2Result out");
    //cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < z.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestAdd_3) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto z = NDArrayFactory::create<double>('c', { 5 }, {10, 10, 10, 10, 10});

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 2, 4, 6, 8, 10 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);

    Nd4jPointer nativeStream = (Nd4jPointer)malloc(sizeof(cudaStream_t));
    CHECK_ALLOC(nativeStream, "Failed to allocate memory for new CUDA stream", sizeof(cudaStream_t));
    cudaError_t dZ = cudaStreamCreate(reinterpret_cast<cudaStream_t *>(&nativeStream));
    auto stream = reinterpret_cast<cudaStream_t *>(&nativeStream);

    //cudaMemcpyAsync(devBufferPtrX, x.buffer(), x.lengthOf() * x.sizeOfT(), cudaMemcpyHostToDevice, *stream);
    //cudaMemcpyAsync(devShapePtrX, x.shapeInfo(), shape::shapeInfoByteLength(x.shapeInfo()), cudaMemcpyHostToDevice, *stream);

    LaunchContext lc(stream, *stream, nullptr, nullptr);
    NativeOpExecutioner::execPairwiseTransform(&lc, pairwise::Add, x.buffer(), x.shapeInfo(), x.specialBuffer(), x.specialShapeInfo(), y.buffer(), y.shapeInfo(), y.specialBuffer(), y.specialShapeInfo(), z.buffer(), z.shapeInfo(), z.specialBuffer(), z.specialShapeInfo(), nullptr);
    auto res = cudaStreamSynchronize(*stream);
    ASSERT_EQ(0, res);
    //double* localBuffer = ;
    cudaMemcpy(z.buffer(), z.specialBuffer(), z.lengthOf() * z.sizeOfT(), cudaMemcpyDeviceToHost);
    res = cudaStreamSynchronize(*stream);
    ASSERT_EQ(0, res);
    x.printBuffer("3X = ");
    y.printBuffer("3Y = ");
    z.printBuffer("3Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < z.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestAdd_4) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 2, 4, 6, 8, 10 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    x.applyPairwiseTransform(pairwise::Add, &y, &z, nullptr);
    z.syncToHost();
    x.printBuffer("3X = ");
    y.printBuffer("3Y = ");
    z.printBuffer("3Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < z.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestAdd_5) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    //auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 2, 4, 6, 8, 10 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    x += y;
    //x.applyPairwiseTransform(pairwise::Add, &y, &z, nullptr);
    x.syncToHost();
    x.printBuffer("33X = ");
    //y.printBuffer("3Y = ");
    //z.printBuffer("3Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < x.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), x.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestAdd_6) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>(2); //.'c', { 5 }, { 1, 2, 3, 4, 5});
    //auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 3, 4, 5, 6, 7 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    x += y;
    //x.applyPairwiseTransform(pairwise::Add, &y, &z, nullptr);
    x.syncToHost();
    x.printBuffer("6X = ");
    //y.printBuffer("3Y = ");
    //z.printBuffer("3Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < x.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), x.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestAdd_7) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    //auto y = NDArrayFactory::create<double>(2); //.'c', { 5 }, { 1, 2, 3, 4, 5});
    //auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 3, 4, 5, 6, 7 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    x += 2.;
    //x.applyPairwiseTransform(pairwise::Add, &y, &z, nullptr);
    x.syncToHost();
    x.printBuffer("7X = ");
    //y.printBuffer("3Y = ");
    //z.printBuffer("3Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < x.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), x.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestMultiply_1) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 1, 4, 9, 16, 25 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    z.syncToHost();
    x.printBuffer("3X = ");
    y.printBuffer("3Y = ");
    z.printBuffer("3Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < z.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestMultiply_2) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    NDArray z('c', { 5 }, nd4j::DataType::DOUBLE);

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 1, 4, 9, 16, 25 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    x.printBuffer("3X = ");
    y.printBuffer("3Y = ");
    z.syncToHost();
    z.printBuffer("3Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < z.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestMultiply_3) {
    // allocating host-side arrays
    NDArray x('c', { 5 }, { 1, 2, 3, 4, 5}, nd4j::DataType::DOUBLE);
    NDArray y('c', { 5 }, { 1., 2., 3., 4., 5.}, nd4j::DataType::DOUBLE);
    auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 1, 4, 9, 16, 25 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    //x.printBuffer("23X = ");
    //y.printBuffer("23Y = ");
    z.syncToHost();
    z.printBuffer("23Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < z.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestMultiply_4) {
    // allocating host-side arrays
    NDArray x('c', { 5 }, { 1, 2, 3, 4, 5}, nd4j::DataType::DOUBLE);
    NDArray y('c', { 5 }, { 1., 2., 3., 4., 5.}, nd4j::DataType::DOUBLE);
    //auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 5 }, { 1, 4, 9, 16, 25 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    //x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    //x.printBuffer("23X = ");
    //y.printBuffer("23Y = ");
    x *= y;
    x.syncToHost();
    x.printBuffer("33Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    for (int e = 0; e < x.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<double>(e), x.e<double>(e), 1e-5);
    }
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestPrimitiveNeg_01) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<int>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<int>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto exp = NDArrayFactory::create<int>('c', { 5 }, { -1, -2, -3, -4, -5 });

    auto stream = x.getContext()->getCudaStream();//reinterpret_cast<cudaStream_t *>(&nativeStream);

    NativeOpExecutioner::execTransformSame(x.getContext(), transform::Neg, x.buffer(), x.shapeInfo(), x.specialBuffer(), x.specialShapeInfo(), y.buffer(), y.shapeInfo(), y.specialBuffer(), y.specialShapeInfo(), nullptr, nullptr, nullptr);
    auto res = cudaStreamSynchronize(*stream);
    ASSERT_EQ(0, res);
    y.syncToHost();

    x.printBuffer("X = ");
    y.printBuffer("Y = ");

    for (int e = 0; e < y.lengthOf(); e++) {
        ASSERT_NEAR(exp.e<int>(e), y.e<int>(e), 1e-5);
    }
}

TEST_F(NDArrayCudaBasicsTests, Test_PrimitiveNeg_2) {
    auto x = NDArrayFactory::create<double>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', {5});

    ASSERT_TRUE(x.isActualOnDeviceSide());
    ASSERT_TRUE(x.isActualOnHostSide());

    x.applyTransform(transform::Neg, &y, nullptr);
    //ASSERT_TRUE(x->isActualOnDeviceSide());
    //ASSERT_FALSE(x->isActualOnHostSide());

    //ASSERT_TRUE(y->isActualOnDeviceSide());
    //ASSERT_TRUE(y->isActualOnHostSide());
    //auto res = cudaStreamSynchronize(*y.getContext()->getCudaStream());
    //ASSERT_EQ(0, res);
    y.syncToHost();
    y.printBuffer("Negatives2");
    //delete x;
    //delete y;
}

TEST_F(NDArrayCudaBasicsTests, Test_PrimitiveSqrt_1) { // strict
    auto x = NDArrayFactory::create<double>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', {5});
    auto exp = NDArrayFactory::create<double>({1.000000, 1.414214, 1.732051, 2.000000, 2.236068});
    ASSERT_TRUE(x.isActualOnDeviceSide());
    ASSERT_TRUE(x.isActualOnHostSide());

    x.applyTransform(transform::Sqrt, &y, nullptr);
    //ASSERT_TRUE(x->isActualOnDeviceSide());
    //ASSERT_FALSE(x->isActualOnHostSide());

    //ASSERT_TRUE(y->isActualOnDeviceSide());
    //ASSERT_TRUE(y->isActualOnHostSide());
    //auto res = cudaStreamSynchronize(*y.getContext()->getCudaStream());
    //ASSERT_EQ(0, res);
    ASSERT_TRUE(y.equalsTo(exp));
    //y.printBuffer("SQRT output");
    //delete x;
    //delete y;
}

TEST_F(NDArrayCudaBasicsTests, Test_PrimitiveAssign_1) { // strict
    auto x = NDArrayFactory::create<double>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', {5});
    //auto exp = NDArrayFactory::create<double>({1.000000, 1.414214, 1.732051, 2.000000, 2.236068});
    //ASSERT_TRUE(x.isActualOnDeviceSide());
    //ASSERT_TRUE(x.isActualOnHostSide());

    x.applyTransform(transform::Assign, &y, nullptr);
    //ASSERT_TRUE(x->isActualOnDeviceSide());
    //ASSERT_FALSE(x->isActualOnHostSide());

    //ASSERT_TRUE(y->isActualOnDeviceSide());
    //ASSERT_TRUE(y->isActualOnHostSide());
    //auto res = cudaStreamSynchronize(*y.getContext()->getCudaStream());
    //ASSERT_EQ(0, res);
    y.syncToHost();
    printf("Assigned to another array\n");
    y.printBuffer("OUput");
    ASSERT_TRUE(y.equalsTo(x));
    //y.syncToHost();
    //y.printBuffer("IsMax output");
    //delete x;
    //delete y;
}

TEST_F(NDArrayCudaBasicsTests, Test_PrimitiveCosine_1) { // strict
    auto x = NDArrayFactory::create<double>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', {5});

    ASSERT_TRUE(x.isActualOnDeviceSide());
    ASSERT_TRUE(x.isActualOnHostSide());

    x.applyTransform(transform::Cosine, &y, nullptr);
    //ASSERT_TRUE(x->isActualOnDeviceSide());
    //ASSERT_FALSE(x->isActualOnHostSide());

    //ASSERT_TRUE(y->isActualOnDeviceSide());
    //ASSERT_TRUE(y->isActualOnHostSide());
    //auto res = cudaStreamSynchronize(*y.getContext()->getCudaStream());
    //ASSERT_EQ(0, res);
    y.syncToHost();
    //y.printBuffer("Cosine2");
    //delete x;
    //delete y;
}

TEST_F(NDArrayCudaBasicsTests, Test_PrimitiveCosine_2) {
    auto x = NDArrayFactory::create<double>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', {5});
    auto exp = NDArrayFactory::create<double>('c', {5}, {0.540302, -0.416147, -0.989992, -0.653644, 0.283662});

    ASSERT_TRUE(x.isActualOnDeviceSide());
    ASSERT_TRUE(x.isActualOnHostSide());
    x.applyTransform(transform::Cosine, &y, nullptr);
    //ASSERT_TRUE(x->isActualOnDeviceSide());
    //ASSERT_FALSE(x->isActualOnHostSide());

    //ASSERT_TRUE(y->isActualOnDeviceSide());
    //ASSERT_TRUE(y->isActualOnHostSide());
    //auto res = cudaStreamSynchronize(*y.getContext()->getCudaStream());
    //ASSERT_EQ(0, res);
    y.syncToHost();
    //exp.syncToHost();
    //y.printBuffer("PrimitiveCosine2");
    //exp.printBuffer("Primitive Cosine exp");
    ASSERT_TRUE(exp.isSameShape(y));
    ASSERT_TRUE(exp.dataType() == y.dataType());
    //for (int e = 0; e < y.lengthOf(); e++) {
    //    ASSERT_NEAR(exp.e<double>(e), y.e<double>(e), 1e-5);
    //}

    ASSERT_TRUE(exp.equalsTo(y));
    //delete x;
    //delete y;
}

TEST_F(NDArrayCudaBasicsTests, Test_PrimitiveCosine_3) {
    auto x = NDArrayFactory::create<double>('c', {5}, {1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>('c', {5});
    auto exp = NDArrayFactory::create<double>({0.540302, -0.416147, -0.989992, -0.653644, 0.283662});

    ASSERT_TRUE(x.isActualOnDeviceSide());
    ASSERT_TRUE(x.isActualOnHostSide());
    x.applyTransform(transform::Cosine, &y, nullptr);
    //ASSERT_TRUE(x->isActualOnDeviceSide());
    //ASSERT_FALSE(x->isActualOnHostSide());

    //ASSERT_TRUE(y->isActualOnDeviceSide());
    //ASSERT_TRUE(y->isActualOnHostSide());
    //auto res = cudaStreamSynchronize(*y.getContext()->getCudaStream());
    //ASSERT_EQ(0, res);
    y.syncToHost();
    //exp.syncToHost();
//    y.printBuffer("PrimitiveCosine3");
//    exp.printBuffer("Primitive Cosine3 exp");
//    y.printShapeInfo("Y shape");
//    exp.printShapeInfo("Exp Shape");
    ASSERT_TRUE(exp.isSameShape(y));
//
//    for (int e = 0; e < y.lengthOf(); e++) {
//        printf("%lf == %lf\n", exp.e<double>(e), y.e<double>(e));
////        ASSERT_NEAR(exp.e<double>(e), y.e<double>(e), 1e-5);
//    }

    ASSERT_TRUE(exp.equalsTo(y));
    //delete x;
    //delete y;
}

TEST_F(NDArrayCudaBasicsTests, TestRawBroadcast_2) {

    //if (!Environment::getInstance()->isExperimentalBuild())
    //    return;

    NDArray x = NDArrayFactory::create<double>('c', {2,3,4});
    NDArray y('c', {2,4},   {10,20,30,40,50,60,70,80}, nd4j::DataType::DOUBLE);
    NDArray z('c', {2,3,4}, {100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100}, nd4j::DataType::DOUBLE);
//    NDArray exp('c', {2,3,4}, {10., 21., 32., 43., 14., 25., 36., 47., 18., 29., 40., 51., 62., 73., 84., 95., 66., 77., 88., 99., 70., 81., 92., 103}, nd4j::DataType::DOUBLE);
    NDArray exp('c', {2,3,4}, {10., 40., 90., 160., 50., 120., 210., 320., 90., 200., 330., 480., 650., 840., 1050., 1280., 850., 1080., 1330., 1600., 1050., 1320., 1610., 1920.}, nd4j::DataType::DOUBLE);
    x.linspace(1); x.syncToDevice();

    std::vector<int> dimensions = {0,2};

    // evaluate xTad data
    shape::TAD xTad(x.getShapeInfo(), dimensions.data(), dimensions.size());
    xTad.createTadOnlyShapeInfo();
    xTad.createOffsets();

    // prepare input arrays for prepareDataForCuda function
    std::vector<std::pair<void*,size_t>> hostData;
    hostData.emplace_back(dimensions.data(), dimensions.size() * sizeof(int));							// 0 -- dimensions
    hostData.emplace_back(xTad.tadOnlyShapeInfo, shape::shapeInfoByteLength(xTad.tadOnlyShapeInfo));	// 1 -- xTadShapeInfo
    hostData.emplace_back(xTad.tadOffsets, xTad.numTads * sizeof(Nd4jLong));							// 2 -- xTadOffsets
    std::vector<void*> devicePtrs(hostData.size(), nullptr);

    // create cuda stream and LaunchContext
    cudaError_t cudaResult;
    cudaStream_t stream;
    cudaResult = cudaStreamCreate(&stream);	ASSERT_EQ(0, cudaResult);
    LaunchContext lc(&stream);

    // allocate required amount of global device memory and copy host data to it
    cudaResult = allocateDeviceMem(lc, devicePtrs, hostData);	ASSERT_EQ(0, cudaResult);

    // call cuda kernel which calculates result
    NativeOpExecutioner::execBroadcast(&lc, nd4j::broadcast::Multiply,
                                       nullptr, x.getShapeInfo(), x.specialBuffer(), x.specialShapeInfo(),
                                       nullptr, y.getShapeInfo(), y.specialBuffer(), y.specialShapeInfo(),
                                       nullptr, z.getShapeInfo(), z.specialBuffer(), z.specialShapeInfo(),
                                       (int*)devicePtrs[0], dimensions.size(),
                                       (Nd4jLong*)devicePtrs[1], (Nd4jLong*)devicePtrs[2],
                                       nullptr, nullptr);

    cudaResult = cudaStreamSynchronize(stream); ASSERT_EQ(0, cudaResult);
    z.syncToHost();
    z.printBuffer("Result with Broadcast2 (multiply)");
    // verify results
    for (int e = 0; e < z.lengthOf(); e++)
        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);

    // free allocated global device memory
    for(int i = 0; i < devicePtrs.size(); ++i)
        cudaFree(devicePtrs[i]);

    // delete cuda stream
    cudaResult = cudaStreamDestroy(stream); ASSERT_EQ(0, cudaResult);
}

TEST_F(NDArrayCudaBasicsTests, TestRawBroadcast_3) {

    //if (!Environment::getInstance()->isExperimentalBuild())
    //    return;

    NDArray x('c', {2,3,4}, nd4j::DataType::DOUBLE);
    NDArray y('c', {2,4},   {10,20,30,40,50,60,70,80}, nd4j::DataType::DOUBLE);
    NDArray z('c', {2,3,4}, {100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100}, nd4j::DataType::DOUBLE);
//    NDArray exp('c', {2,3,4}, {10., 21., 32., 43., 14., 25., 36., 47., 18., 29., 40., 51., 62., 73., 84., 95., 66., 77., 88., 99., 70., 81., 92., 103}, nd4j::DataType::DOUBLE);
    NDArray exp('c', {2,3,4}, {10., 40., 90., 160., 50., 120., 210., 320., 90., 200., 330., 480., 650., 840., 1050., 1280., 850., 1080., 1330., 1600., 1050., 1320., 1610., 1920.}, nd4j::DataType::DOUBLE);
    x.linspace(1); x.syncToDevice();

    std::vector<int> dimensions = {0,2};

    // evaluate xTad data
    shape::TAD xTad(x.getShapeInfo(), dimensions.data(), dimensions.size());
    xTad.createTadOnlyShapeInfo();
    xTad.createOffsets();

    // prepare input arrays for prepareDataForCuda function
    std::vector<std::pair<void*,size_t>> hostData;
    hostData.emplace_back(dimensions.data(), dimensions.size() * sizeof(int));							// 0 -- dimensions
    hostData.emplace_back(xTad.tadOnlyShapeInfo, shape::shapeInfoByteLength(xTad.tadOnlyShapeInfo));	// 1 -- xTadShapeInfo
    hostData.emplace_back(xTad.tadOffsets, xTad.numTads * sizeof(Nd4jLong));							// 2 -- xTadOffsets
    std::vector<void*> devicePtrs(hostData.size(), nullptr);

    // create cuda stream and LaunchContext
    cudaError_t cudaResult;
    //cudaStream_t stream;
    //cudaResult = cudaStreamCreate(&stream);	ASSERT_EQ(0, cudaResult);
    LaunchContext* pLc = x.getContext();//(&stream);
    cudaStream_t* stream = pLc->getCudaStream();
    // allocate required amount of global device memory and copy host data to it
//    cudaResult = allocateDeviceMem(*pLc, devicePtrs, hostData);	ASSERT_EQ(0, cudaResult);
    for(int i = 0; i < devicePtrs.size(); ++i) {

        cudaResult = cudaMalloc(reinterpret_cast<void **>(&devicePtrs[i]), hostData[i].second); ASSERT_EQ(0, cudaResult);
        cudaMemcpyAsync(devicePtrs[i], hostData[i].first, hostData[i].second, cudaMemcpyHostToDevice, *stream);
    }

    NDArray::registerSpecialUse({&z}, {&x, &y});
    // call cuda kernel which calculates result
    NativeOpExecutioner::execBroadcast(pLc, nd4j::broadcast::Multiply,
                                       nullptr, x.getShapeInfo(), x.specialBuffer(), x.specialShapeInfo(),
                                       nullptr, y.getShapeInfo(), y.specialBuffer(), y.specialShapeInfo(),
                                       nullptr, z.getShapeInfo(), z.specialBuffer(), z.specialShapeInfo(),
                                       (int*)devicePtrs[0], dimensions.size(),
                                       (Nd4jLong*)devicePtrs[1], (Nd4jLong*)devicePtrs[2],
                                       nullptr, nullptr);

    //cudaResult = cudaStreamSynchronize(stream); ASSERT_EQ(0, cudaResult);
    z.syncToHost();
    z.printBuffer("Result with Broadcast3 (multiply)");
    // verify results
    for (int e = 0; e < z.lengthOf(); e++)
        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);

    // free allocated global device memory
    for(int i = 0; i < devicePtrs.size(); ++i)
        cudaFree(devicePtrs[i]);
    ASSERT_TRUE(exp.equalsTo(z));
    // delete cuda stream
    //cudaResult = cudaStreamDestroy(stream); ASSERT_EQ(0, cudaResult);
}


TEST_F(NDArrayCudaBasicsTests, TestBroadcastMultiply_1) {
    // allocating host-side arrays
    NDArray x('c', { 2, 3 }, { 1, 2, 3, 4, 5, 6}, nd4j::DataType::DOUBLE);
    NDArray y = NDArrayFactory::create<double>(3.); //'c', { 3 }, { 2., 3., 4.}, nd4j::DataType::DOUBLE);
    //auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 2, 3 }, { 3, 6, 9, 12, 15, 18 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    //x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    //x.printBuffer("23X = ");
    //y.printBuffer("23Y = ");
    x *= y;
    x.syncToHost();
    x.printBuffer("54Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);
    ASSERT_TRUE(exp.equalsTo(x));
//    for (int e = 0; e < x.lengthOf(); e++) {
//        ASSERT_NEAR(exp.e<double>(e), x.e<double>(e), 1e-5);
//    }
}

TEST_F(NDArrayCudaBasicsTests, TestBroadcastMultiply_01) {
    // allocating host-side arrays
    NDArray x('c', { 2, 3 }, { 1, 2, 3, 4, 5, 6}, nd4j::DataType::DOUBLE);
    NDArray y = NDArrayFactory::create<double>(3.); //'c', { 3 }, { 2., 3., 4.}, nd4j::DataType::DOUBLE);
    auto z = NDArrayFactory::create<double>('c', { 2, 3 });

    auto exp = NDArrayFactory::create<double>('c', { 2, 3 }, { 3, 6, 9, 12, 15, 18 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    //x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    //x.printBuffer("23X = ");
    //y.printBuffer("23Y = ");
    x.applyTrueBroadcast(BroadcastOpsTuple::Multiply(), &y, &z);// *= y;
    z.syncToHost();
    z.printBuffer("53Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);
    ASSERT_TRUE(exp.equalsTo(z));

//    for (int e = 0; e < x.lengthOf(); e++) {
//        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
//    }
}

TEST_F(NDArrayCudaBasicsTests, TestBroadcastMultiply_02) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 2, 3 }, { 1, 2, 3, 4, 5, 6}); //, nd4j::DataType::DOUBLE);
    auto y = NDArrayFactory::create<double>('c', {2,3}, {3, 3, 3, 3, 3, 3}); //'c', { 3 }, { 2., 3., 4.}, nd4j::DataType::DOUBLE);
    auto z = NDArrayFactory::create<double>('c', { 2, 3 });

    auto exp = NDArrayFactory::create<double>('c', { 2, 3 }, { 3, 6, 9, 12, 15, 18 });
    //if (x.isActualOnHostSide() && !x.isActualOnDeviceSide())
    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    //x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    //x.printBuffer("23X = ");
    //y.printBuffer("23Y = ");
    x.applyTrueBroadcast(BroadcastOpsTuple::Multiply(), &y, &z);// *= y;
    //z.lazyAllocateBuffer();
    z.syncToHost();
    z.printBuffer("52Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);
    //ASSERT_TRUE(exp.equalsTo(z));

//    for (int e = 0; e < x.lengthOf(); e++) {
//        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
//    }
}

TEST_F(NDArrayCudaBasicsTests, TestBroadcastMultiply_002) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 2, 3 }, { 1, 2, 3, 4, 5, 6}); //, nd4j::DataType::DOUBLE);
    auto y = NDArrayFactory::create<double>('c', {2, 3}, {2., 3., 3., 3., 3., 3.}); //'c', { 3 }, { 2., 3., 4.}, nd4j::DataType::DOUBLE);
    auto z = NDArrayFactory::create<double>('c', { 2, 3 });

    auto exp = NDArrayFactory::create<double>('c', { 2, 3 }, { 2, 6, 9, 12, 15, 18 });
    //if (x.isActualOnHostSide() && !x.isActualOnDeviceSide())
    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    //x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    //x.printBuffer("23X = ");
    //y.printBuffer("23Y = ");
    x.applyPairwiseTransform(pairwise::Multiply, &y, &z);// *= y;
    //z.lazyAllocateBuffer();
    z.syncToHost();
    z.printBuffer("51Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);
    //ASSERT_TRUE(exp.equalsTo(z));

//    for (int e = 0; e < x.lengthOf(); e++) {
//        ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);
//    }
}

////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestBroadcastRaw_1) {

    //if (!Environment::getInstance()->isExperimentalBuild())
    //    return;

    NDArray x('c', {2,3,4}, {100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100}, nd4j::DataType::INT32);
    NDArray y('c', {3},   {10, 20, 30}, nd4j::DataType::INT64);
    NDArray z('c', {2,3,4}, {100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100}, nd4j::DataType::INT32);
    NDArray exp('c', {2,3,4}, {10, 11, 12, 13,24, 25, 26, 27,38, 39, 40, 41,22, 23, 24, 25,36, 37, 38, 39,50, 51, 52, 53}, nd4j::DataType::INT32);
    //real output [10, 11, 12, 13, 4, 5, 6, 7, 28, 29, 30, 31, 22, 23, 24, 25, 16, 17, 18, 19, 40, 41, 42, 43]
    x.linspace(0); x.syncToDevice();

    std::vector<int> dimensions = {1};

    // evaluate xTad data
    shape::TAD xTad(x.getShapeInfo(), dimensions.data(), dimensions.size());
    xTad.createTadOnlyShapeInfo();
    xTad.createOffsets();

    // prepare input arrays for prepareDataForCuda function
    std::vector<std::pair<void*,size_t>> hostData;
    hostData.emplace_back(dimensions.data(), dimensions.size() * sizeof(Nd4jLong));							// 0 -- dimensions
    hostData.emplace_back(xTad.tadOnlyShapeInfo, shape::shapeInfoByteLength(xTad.tadOnlyShapeInfo));	// 1 -- xTadShapeInfo
    hostData.emplace_back(xTad.tadOffsets, xTad.numTads * sizeof(Nd4jLong));							// 2 -- xTadOffsets
    std::vector<void*> devicePtrs(hostData.size(), nullptr);

    // create cuda stream and LaunchContext
    cudaError_t cudaResult;
    cudaStream_t* stream = x.getContext()->getCudaStream();
    LaunchContext* pLc = x.getContext();

    // allocate required amount of global device memory and copy host data to it
    //cudaResult = allocateDeviceMem(*pLc, devicePtrs, hostData);	ASSERT_EQ(0, cudaResult);
    for(size_t i = 0; i < devicePtrs.size(); ++i) {
        nd4j_printf("Allocation of %i bytes with device\n", hostData[i].second)
        cudaResult = cudaMalloc(&devicePtrs[i], hostData[i].second); //if(cudaResult != 0) return cudaResult;
        ASSERT_EQ(cudaResult, 0);
        cudaMemcpy(devicePtrs[i], hostData[i].first, hostData[i].second, cudaMemcpyHostToDevice);
    }

    // call cuda kernel which calculates result
    NativeOpExecutioner::execBroadcast(pLc, nd4j::broadcast::Add,
                                       nullptr, x.getShapeInfo(), x.specialBuffer(), x.specialShapeInfo(),
                                       nullptr, y.getShapeInfo(), y.specialBuffer(), y.specialShapeInfo(),
                                       nullptr, z.getShapeInfo(), z.specialBuffer(), z.specialShapeInfo(),
                                       (int*)devicePtrs[0], dimensions.size(),
                                       (Nd4jLong*)devicePtrs[1], (Nd4jLong*)devicePtrs[2],
                                       nullptr, nullptr);

    cudaResult = cudaStreamSynchronize(*stream); ASSERT_EQ(0, cudaResult);
    z.syncToHost();
    x.printIndexedBuffer(" X");
    y.printIndexedBuffer("+Y");
    z.printBuffer("ADD broadcasted output");
    // verify results
   // for (int e = 0; e < z.lengthOf(); e++)
   //     ASSERT_NEAR(exp.e<double>(e), z.e<double>(e), 1e-5);

    // free allocated global device memory
    for(int i = 0; i < devicePtrs.size(); ++i)
        cudaFree(devicePtrs[i]);

    // delete cuda stream
    //cudaResult = cudaStreamDestroy(stream); ASSERT_EQ(0, cudaResult);
}

TEST_F(NDArrayCudaBasicsTests, TestBroadcastMultiply) {
    // allocating host-side arrays
    NDArray x('c', { 2, 3 }, { 1, 2, 3, 4, 5, 6}, nd4j::DataType::DOUBLE);
    NDArray y('c', { 3 }, { 2., 3., 4.}, nd4j::DataType::DOUBLE);
    //auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 2, 3 }, { 2, 6, 12, 8, 15, 24 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    //x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    //x.printBuffer("23X = ");
    //y.printBuffer("23Y = ");
    x *= y;
    x.syncToHost();
    x.printBuffer("55Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    //for (int e = 0; e < x.lengthOf(); e++) {
    //    ASSERT_NEAR(exp.e<double>(e), x.e<double>(e), 1e-5);
    //}
}


TEST_F(NDArrayCudaBasicsTests, TestBroadcastMultiply_2) {
    // allocating host-side arrays
    NDArray x('c', { 2, 3 }, { 1, 2, 3, 4, 5, 6}, nd4j::DataType::DOUBLE);
    NDArray y('c', { 3 }, { 2., 3., 4.}, nd4j::DataType::DOUBLE);
    //auto z = NDArrayFactory::create<double>('c', { 5 });

    auto exp = NDArrayFactory::create<double>('c', { 2, 3 }, { 11,12, 13,14, 15, 16 });
    auto expZ = NDArrayFactory::create<double>('c', { 2, 3 }, { 2, 6, 12, 8, 15, 24 });

    // making raw buffers
    //Nd4jPointer devBufferPtrX, devBufferPtrZ, devShapePtrX;
    //cudaError_t res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrX), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devBufferPtrZ), x.lengthOf() * x.sizeOfT());
    //ASSERT_EQ(0, res);
    //res = cudaMalloc(reinterpret_cast<void **>(&devShapePtrX), shape::shapeInfoByteLength(x.shapeInfo()));
    //ASSERT_EQ(0, res);
    //x.applyPairwiseTransform(pairwise::Multiply, &y, &z, nullptr);
    //x.printBuffer("23X = ");
    //y.printBuffer("23Y = ");
    //void NDArray::applyTrueBroadcast(nd4j::BroadcastOpsTuple op, const NDArray* other, NDArray* target, const bool checkTargetShape, ExtraArguments *extraArgs)
    x.applyTrueBroadcast(BroadcastOpsTuple::Multiply(), &y, &exp);
    exp.syncToHost();
    exp.printBuffer("56Result out");

    //
    // cudaFree(devBufferPtrX);
    //cudaFree(devBufferPtrZ);
    //cudaFree(devShapePtrX);

    //for (int e = 0; e < x.lengthOf(); e++) {
    //    ASSERT_NEAR(exp.e<double>(e), x.e<double>(e), 1e-5);
    //}
    ASSERT_TRUE(exp.equalsTo(expZ));

}


//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestReduceSum_1) {
    // allocating host-side arrays
    auto x = NDArrayFactory::create<double>('c', { 5 }, { 1, 2, 3, 4, 5});
    auto y = NDArrayFactory::create<double>(15);
    auto exp = NDArrayFactory::create<double>(15);

    auto stream = x.getContext()->getCudaStream();//reinterpret_cast<cudaStream_t *>(&nativeStream);

    NativeOpExecutioner::execReduceSameScalar(x.getContext(), reduce::Sum, x.buffer(), x.shapeInfo(), x.specialBuffer(), x.specialShapeInfo(), nullptr, y.buffer(), y.shapeInfo(), y.specialBuffer(), y.specialShapeInfo());
    auto res = cudaStreamSynchronize(*stream);
    ASSERT_EQ(0, res);
    y.syncToHost();

    x.printBuffer("X = ");
    y.printBuffer("Y = ");
    ASSERT_NEAR(y.e<double>(0), 15, 1e-5);
}

//////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, TestDup1) {
    float arr1[6] = {1,2,3,4,5,6};
    Nd4jLong shape1[8] = {2,2,3,3,1,8192,1,99};
    NDArray array(arr1, shape1);
    array.printBuffer("Array at start");
    auto arrC = array.dup('c');
    auto arrF = array.dup('f');
    arrC->printBuffer("arrC");
    arrF->printBuffer("arrF");
    //arrC->printShapeInfo("C shape");
    //arrF->printShapeInfo("F shape");

    ASSERT_TRUE(array.equalsTo(arrF));
    ASSERT_TRUE(array.equalsTo(arrC));

    ASSERT_TRUE(arrF->equalsTo(arrC));

    delete arrC;
    delete arrF;
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, equalsTo_1) {
               
    NDArray x('c', {2,5}, {1,2,3,4,5,6,7,8,9,10}, nd4j::DataType::DOUBLE);
    NDArray y('c', {2,5}, {1,2,3,4,5,6,7,8,9,10}, nd4j::DataType::DOUBLE);
    
    ASSERT_TRUE(x.equalsTo(y));

    x.permutei({1,0});
    y.permutei({1,0});

    ASSERT_TRUE(x.equalsTo(y));
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, equalsTo_2) {

    NDArray x('c', {2,5}, {1,2,3,4,5,6,7,8,10,10}, nd4j::DataType::DOUBLE);
    NDArray y('c', {2,5}, {1,2,5,4,5,6,7,8,9,10}, nd4j::DataType::DOUBLE);

    ASSERT_FALSE(x.equalsTo(y));

    x.permutei({1,0});
    y.permutei({1,0});

    ASSERT_FALSE(x.equalsTo(y));
}

//////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, equalsTo_3) {

    NDArray x('c', {2,5}, {1,2,3,4,5,6,7,8,9,10}, nd4j::DataType::DOUBLE);
    NDArray y('c', {2,5}, {1.f,2.f,3.f,4.f,5.f,6.f,7.f,8.f,9.f,10.f}, nd4j::DataType::FLOAT32);

    ASSERT_FALSE(x.equalsTo(y));

    x.permutei({1,0});
    y.permutei({1,0});

    ASSERT_FALSE(x.equalsTo(y));
}

////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, applyReduce3_1) {
    
    NDArray x('c', {2,3,4}, {-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13}, nd4j::DataType::INT32);
    NDArray x2('c', {2,3,4}, {-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13}, nd4j::DataType::INT32);
    NDArray y('c', {2,3,4}, {-2,3,-4,5,-2,3,-4,5,-2,3,-4,5,-2,3,-4,5,-2,3,-4,5,-2,3,-4,5}, nd4j::DataType::INT32);    
    NDArray k('c', {2,3}, {-2,3,-4,5,-2,3}, nd4j::DataType::INT32);
    NDArray k2('c', {3,2}, {-2,3,-4,5,-2,3}, nd4j::DataType::INT32);
        
    NDArray exp1('c', {3}, {4., 20., 36.}, nd4j::DataType::FLOAT32);
    NDArray exp2('c', {2,3}, {-10., -2., 6.,14., 22., 30.}, nd4j::DataType::FLOAT32);
    NDArray exp3('c', {4}, {38., 41., 44., 47.}, nd4j::DataType::FLOAT32);
    NDArray exp4('c', {4}, {114., 117., 120., 123.}, nd4j::DataType::FLOAT32);
    

    NDArray* z = x.applyReduce3(nd4j::reduce3::Dot, &y, {0,2});
    ASSERT_TRUE(z->equalsTo(&exp1));    
    delete z; 

    z = x.applyReduce3(nd4j::reduce3::Dot, &k, {0,1});
    ASSERT_TRUE(z->equalsTo(&exp3));    
    delete z; 

    x.permutei({0,2,1});
    y.permutei({0,2,1});

    z = y.applyReduce3(nd4j::reduce3::Dot, &x, {1});
    ASSERT_TRUE(z->equalsTo(&exp2));    
    // printCudaGlobal<float><<<1,1,0, *y.getContext()->getCudaStream()>>>(z->specialBuffer(), 6);
    delete z;    

    x2.permutei({1,0,2});

    z = x2.applyReduce3(nd4j::reduce3::Dot, &k2, {0,1});
    ASSERT_TRUE(z->equalsTo(&exp4));    
    delete z; 
}

////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, applyReduce3_2) {
    
    NDArray x('c', {2,3,4}, {-10,-9,-8.5,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13}, nd4j::DataType::DOUBLE);
    NDArray x2('c', {2,3,4}, {-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0.5,1,2,3,4,5,6,7,8,9,10,11,12,13}, nd4j::DataType::DOUBLE);
    NDArray y('c', {2,3,4}, {-2,3,-4,5,-2,3,-4,5,-2,3,-4,5,-2.5,3,-4,5,-2,3,-4,5,-2,3,-4,5}, nd4j::DataType::DOUBLE);    
    NDArray k('c', {2,3}, {-2,3,-4,5.5,-2,3}, nd4j::DataType::DOUBLE);
    NDArray k2('c', {3,2}, {-2,3,-4,5,-2,3.5}, nd4j::DataType::DOUBLE);
    
    NDArray exp1('c', {3}, {5., 20., 36.}, nd4j::DataType::DOUBLE);
    NDArray exp2('c', {2,3}, {-8., -2., 6., 13., 22., 30.}, nd4j::DataType::DOUBLE);
    NDArray exp3('c', {4}, {39., 42.5, 47., 49.5}, nd4j::DataType::DOUBLE);
    NDArray exp4('c', {4}, {119., 122.5, 125., 129.5}, nd4j::DataType::DOUBLE);
    
    NDArray* z = x.applyReduce3(nd4j::reduce3::Dot, &y, {0,2});
    ASSERT_TRUE(z->equalsTo(&exp1));    
    delete z; 

    z = x.applyReduce3(nd4j::reduce3::Dot, &k, {0,1});
    ASSERT_TRUE(z->equalsTo(&exp3));    
    delete z; 

    x.permutei({0,2,1});
    y.permutei({0,2,1});

    z = y.applyReduce3(nd4j::reduce3::Dot, &x, {1});
    ASSERT_TRUE(z->equalsTo(&exp2));    
    // printCudaGlobal<float><<<1,1,0, *y.getContext()->getCudaStream()>>>(z->specialBuffer(), 6);
    delete z;    

    x2.permutei({1,0,2});

    z = x2.applyReduce3(nd4j::reduce3::Dot, &k2, {0,1});
    ASSERT_TRUE(z->equalsTo(&exp4));    
    delete z; 
}

////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, applyReduce3_3) {
    
    NDArray x1('c', {2,2,2}, {1,2,3,4,5,6,7,8}, nd4j::DataType::INT32);
    NDArray x2('c', {2,2,2}, {-1,-2,-3,-4,-5,-6,-7,-8}, nd4j::DataType::INT32);
    NDArray x3('c', {3,2}, {1.5,1.5,1.5,1.5,1.5,1.5}, nd4j::DataType::DOUBLE);
    NDArray x4('c', {3,2}, {1,2,3,4,5,6}, nd4j::DataType::DOUBLE);
    
    NDArray exp1('c', {0}, {-204}, nd4j::DataType::FLOAT32);
    NDArray exp2('c', {0}, {31.5}, nd4j::DataType::DOUBLE);
    
    
    auto z = x1.applyReduce3(reduce3::Dot, &x2);
    ASSERT_TRUE(z->equalsTo(&exp1));
    delete z;

    z = x3.applyReduce3(reduce3::Dot, &x4);    
    ASSERT_TRUE(z->equalsTo(&exp2));
    delete z;

    x1.permutei({2,1,0});
    x2.permutei({2,1,0});
    x3.permutei({1,0});
    x4.permutei({1,0});

    z = x1.applyReduce3(reduce3::Dot, &x2);
    ASSERT_TRUE(z->equalsTo(&exp1));
    delete z;

    z = x3.applyReduce3(reduce3::Dot, &x4);    
    ASSERT_TRUE(z->equalsTo(&exp2));
    delete z;
}

////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, applyAllReduce3_1) {
    
    NDArray x1('c', {2,3,2}, {1,2,3,4,5,6,7,8,-1,-2,-3,-4,}, nd4j::DataType::INT32);
    NDArray x2('c', {2,2,2}, {-1,-2,-3,-4,-5,-6,-7,-8}, nd4j::DataType::INT32);
    NDArray x3('c', {3,2}, {1.5,1.5,1.5,1.5,1.5,1.5}, nd4j::DataType::DOUBLE);
    NDArray x4('c', {3,2}, {1,2,3,4,5,6}, nd4j::DataType::DOUBLE);

    NDArray exp1('c', {3,2}, {-88., -124., 6., -2., 22., 14.}, nd4j::DataType::FLOAT32);
    NDArray exp2('c', {6,4}, {-36., -44., -52., -60.,-42., -52., -62., -72.,2., 0., -2., -4.,6., 4., 2., 0.,10., 8., 6., 4.,14., 12., 10., 8.}, nd4j::DataType::FLOAT32);
    NDArray exp3('c', {1,1}, {31.5}, nd4j::DataType::DOUBLE);
    NDArray exp4('c', {3,3}, {4.5, 10.5, 16.5,4.5, 10.5, 16.5,4.5, 10.5, 16.5}, nd4j::DataType::DOUBLE);

    auto z = x1.applyAllReduce3(reduce3::Dot, &x2, {0,2});
    ASSERT_TRUE(z->equalsTo(&exp1));
    delete z;

    z = x1.applyAllReduce3(reduce3::Dot, &x2, {0});
    ASSERT_TRUE(z->equalsTo(&exp2));
    delete z;

    z = x3.applyAllReduce3(reduce3::Dot, &x4, {0,1});
    ASSERT_TRUE(z->equalsTo(&exp3));
    delete z;

    z = x3.applyAllReduce3(reduce3::Dot, &x4, {1});
    // z->syncToHost();
    // z->printShapeInfo();
    // z->printIndexedBuffer();
    ASSERT_TRUE(z->equalsTo(&exp4));
    delete z;

    x1.permutei({2,1,0});
    x2.permutei({2,1,0});
    x3.permutei({1,0});
    x4.permutei({1,0});

    z = x1.applyAllReduce3(reduce3::Dot, &x2, {0,2});
    ASSERT_TRUE(z->equalsTo(&exp1));
    delete z;

    z = x3.applyAllReduce3(reduce3::Dot, &x4, {0});
    ASSERT_TRUE(z->equalsTo(&exp4));
    delete z;
}

//////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, applyIndexReduce_test1) {

    NDArray x('c', {2,3}, {0, 10, 1, 2, 2.5,-4}, nd4j::DataType::DOUBLE);
    
    NDArray scalar('c', {0}, {100}, nd4j::DataType::INT64);
    NDArray vec1('c', {2}, {100,100}, nd4j::DataType::INT64);
    NDArray vec2('c', {3}, {100,100,100}, nd4j::DataType::INT64);
    
    NDArray exp1('c', {0}, {1}, nd4j::DataType::INT64);
    NDArray exp2('c', {2}, {1,1}, nd4j::DataType::INT64);
    NDArray exp3('c', {3}, {1,0,0}, nd4j::DataType::INT64);

    NDArray exp4('c', {0}, {2}, nd4j::DataType::INT64);
    NDArray exp5('c', {2}, {1,1}, nd4j::DataType::INT64);
    NDArray exp6('c', {3}, {1,0,0}, nd4j::DataType::INT64);
    
    x.applyIndexReduce(nd4j::indexreduce::IndexMax, &scalar, {0,1});
    ASSERT_TRUE(scalar.equalsTo(&exp1));

    x.applyIndexReduce(nd4j::indexreduce::IndexMax, &vec1, {1});    
    ASSERT_TRUE(vec1.equalsTo(&exp2));

    x.applyIndexReduce(nd4j::indexreduce::IndexMax, &vec2, {0});
    ASSERT_TRUE(vec2.equalsTo(&exp3));

    x.permutei({1,0});

    x.applyIndexReduce(nd4j::indexreduce::IndexMax, &scalar, {0,1});
    ASSERT_TRUE(scalar.equalsTo(&exp4));

    x.applyIndexReduce(nd4j::indexreduce::IndexMax, &vec1, {0});        
    ASSERT_TRUE(vec1.equalsTo(&exp5));

    x.applyIndexReduce(nd4j::indexreduce::IndexMax, &vec2, {1});
    ASSERT_TRUE(vec2.equalsTo(&exp6));
}


//////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, applyIndexReduce_test2) {

    NDArray x('c', {2,3}, {0, 10, 1, 2, 2.5,-4}, nd4j::DataType::DOUBLE);    
    
    NDArray exp1('c', {0}, {1}, nd4j::DataType::INT64);
    NDArray exp2('c', {2}, {1,1}, nd4j::DataType::INT64);
    NDArray exp3('c', {3}, {1,0,0}, nd4j::DataType::INT64);

    NDArray exp4('c', {0}, {2}, nd4j::DataType::INT64);
    NDArray exp5('c', {2}, {1,1}, nd4j::DataType::INT64);
    NDArray exp6('c', {3}, {1,0,0}, nd4j::DataType::INT64);
    
    auto z = x.applyIndexReduce(nd4j::indexreduce::IndexMax, {0,1});
    ASSERT_TRUE(z->equalsTo(&exp1));
    delete z;

    z = x.applyIndexReduce(nd4j::indexreduce::IndexMax, {1});    
    ASSERT_TRUE(z->equalsTo(&exp2));
    delete z;

    z = x.applyIndexReduce(nd4j::indexreduce::IndexMax, {0});
    ASSERT_TRUE(z->equalsTo(&exp3));
    delete z;

    x.permutei({1,0});

    z = x.applyIndexReduce(nd4j::indexreduce::IndexMax, {0,1});
    ASSERT_TRUE(z->equalsTo(&exp4));
    delete z;

    z = x.applyIndexReduce(nd4j::indexreduce::IndexMax, {0});        
    ASSERT_TRUE(z->equalsTo(&exp5));
    delete z;

    z = x.applyIndexReduce(nd4j::indexreduce::IndexMax, {1});
    ASSERT_TRUE(z->equalsTo(&exp6));
    delete z;
}

////////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, reduceAlongDimension_float_test1) {
    
    NDArray x('c', {2,3,2}, {1,2,3,4,5,6,7,8,-1,-2,-3,-4,}, nd4j::DataType::INT32);

    NDArray z1('c', {0}, {100}, nd4j::DataType::DOUBLE);    
    NDArray z2('c', {2,2}, {100,100,100,100}, nd4j::DataType::FLOAT32);
    NDArray z3('c', {3}, {100,100,100}, nd4j::DataType::DOUBLE);
    NDArray z4('c', {3,2}, {100,100,100,100,100,100}, nd4j::DataType::FLOAT32);
    NDArray z5('c', {2}, {100,100}, nd4j::DataType::FLOAT32);

    NDArray exp1('c', {0}, {2.166667}, nd4j::DataType::DOUBLE);    
    NDArray exp2('c', {2,2}, {3,4,1,0.666667}, nd4j::DataType::FLOAT32);
    NDArray exp3('c', {3}, {4.5,1,1}, nd4j::DataType::DOUBLE);
    NDArray exp4('c', {3,2}, {4,5,1,1,1,1}, nd4j::DataType::FLOAT32);
    NDArray exp5('c', {2}, {3.5,0.833333}, nd4j::DataType::FLOAT32);
    
    x.reduceAlongDimension(nd4j::reduce::Mean, &z1, {0,1,2});    
    ASSERT_TRUE(z1.equalsTo(&exp1));
    
    x.reduceAlongDimension(nd4j::reduce::Mean, &z2, {1});
    ASSERT_TRUE(z2.equalsTo(&exp2));

    x.reduceAlongDimension(nd4j::reduce::Mean, &z3, {0,2});
    ASSERT_TRUE(z3.equalsTo(&exp3));

    x.permutei({1,0,2});    // 3x2x2

    x.reduceAlongDimension(nd4j::reduce::Mean, &z1, {0,1,2});    
    ASSERT_TRUE(z1.equalsTo(&exp1));

    x.reduceAlongDimension(nd4j::reduce::Mean, &z4, {1});
    ASSERT_TRUE(z4.equalsTo(&exp4));

    x.reduceAlongDimension(nd4j::reduce::Mean, &z5, {0,2});
    ASSERT_TRUE(z5.equalsTo(&exp5));  
}

////////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, reduceAlongDimension_float_test2) {
    
    NDArray x('c', {2,3,2}, {1,2,3,4,5,6,7,8,-1,-2,-3,-4,}, nd4j::DataType::DOUBLE);

    NDArray exp1('c', {0}, {2.166667}, nd4j::DataType::DOUBLE);    
    NDArray exp2('c', {2,2}, {3,4,1,0.666667}, nd4j::DataType::DOUBLE);
    NDArray exp3('c', {3}, {4.5,1,1}, nd4j::DataType::DOUBLE);
    NDArray exp4('c', {3,2}, {4,5,1,1,1,1}, nd4j::DataType::DOUBLE);
    NDArray exp5('c', {2}, {3.5,0.833333}, nd4j::DataType::DOUBLE);
    
    NDArray z1 = x.reduceAlongDims(nd4j::reduce::Mean, {0,1,2});
    ASSERT_TRUE(z1.equalsTo(&exp1));    
    
    NDArray z2 = x.reduceAlongDims(nd4j::reduce::Mean, {1});
    ASSERT_TRUE(z2.equalsTo(&exp2));    

    NDArray z3 = x.reduceAlongDims(nd4j::reduce::Mean, {0,2});
    ASSERT_TRUE(z3.equalsTo(&exp3));    

    x.permutei({1,0,2});    // 3x2x2

    NDArray z4 = x.reduceAlongDims(nd4j::reduce::Mean, {0,1,2});    
    ASSERT_TRUE(z4.equalsTo(&exp1));

    NDArray z5 = x.reduceAlongDims(nd4j::reduce::Mean, {1});
    ASSERT_TRUE(z5.equalsTo(&exp4));

    NDArray z6 = x.reduceAlongDims(nd4j::reduce::Mean, {0,2});
    ASSERT_TRUE(z6.equalsTo(&exp5));      
}

//////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, EqualityTest1) {
    auto arrayA = NDArrayFactory::create_<float>('f', {3, 5});
    auto arrayB = NDArrayFactory::create_<float>('f', {3, 5});
    auto arrayC = NDArrayFactory::create_<float>('f', {3, 5});

    auto arrayD = NDArrayFactory::create_<float>('f', {2, 4});
    auto arrayE = NDArrayFactory::create_<float>('f', {1, 15});

    for (int i = 0; i < arrayA->rows(); i++) {
        for (int k = 0; k < arrayA->columns(); k++) {
            arrayA->p(i, k, (float) i);
        }
    }
    arrayA->printBuffer("arrayA is ");
    for (int i = 0; i < arrayB->rows(); i++) {
        for (int k = 0; k < arrayB->columns(); k++) {
            arrayB->p(i, k, (float) i);
        }
    }
    arrayB->printBuffer("arrayB is ");

    for (int i = 0; i < arrayC->rows(); i++) {
        for (int k = 0; k < arrayC->columns(); k++) {
            arrayC->p(i, k, (float) i+1);
        }
    }
    arrayC->printBuffer("arrayC is ");



    ASSERT_TRUE(arrayA->equalsTo(arrayB, 1e-5));

    ASSERT_FALSE(arrayC->equalsTo(arrayB, 1e-5));

    ASSERT_FALSE(arrayD->equalsTo(arrayB, 1e-5));

    ASSERT_FALSE(arrayE->equalsTo(arrayB, 1e-5));

    delete arrayA;
    delete arrayB;
    delete arrayC;
    delete arrayD;
    delete arrayE;
}

////////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, reduceAlongDimension_same_test1) {
    
    NDArray x('c', {2,3,2}, {1.5,2,3,4,5,6,7.5,8,-1,-2,-3.5,-4,}, nd4j::DataType::FLOAT32);

    NDArray z1('c', {0}, {100}, nd4j::DataType::FLOAT32);    
    NDArray z2('c', {2,2}, {100,100,100,100}, nd4j::DataType::FLOAT32);
    NDArray z3('c', {3}, {100,100,100}, nd4j::DataType::FLOAT32);
    NDArray z4('c', {3,2}, {100,100,100,100,100,100}, nd4j::DataType::FLOAT32);
    NDArray z5('c', {2}, {100,100}, nd4j::DataType::FLOAT32);

    NDArray exp1('c', {0}, {26.5}, nd4j::DataType::FLOAT32);    
    NDArray exp2('c', {2,2}, {9.5,12,3,2}, nd4j::DataType::FLOAT32);
    NDArray exp3('c', {3}, {19,4,3.5}, nd4j::DataType::FLOAT32);
    NDArray exp4('c', {3,2}, {9,10,2,2,1.5,2}, nd4j::DataType::FLOAT32);
    NDArray exp5('c', {2}, {21.5,5}, nd4j::DataType::FLOAT32);
    
    x.reduceAlongDimension(nd4j::reduce::Sum, &z1, {0,1,2});    
    ASSERT_TRUE(z1.equalsTo(&exp1));
    
    x.reduceAlongDimension(nd4j::reduce::Sum, &z2, {1});
    ASSERT_TRUE(z2.equalsTo(&exp2));

    x.reduceAlongDimension(nd4j::reduce::Sum, &z3, {0,2});
    ASSERT_TRUE(z3.equalsTo(&exp3));

    x.permutei({1,0,2});    // 3x2x2

    x.reduceAlongDimension(nd4j::reduce::Sum, &z1, {0,1,2});    
    ASSERT_TRUE(z1.equalsTo(&exp1));

    x.reduceAlongDimension(nd4j::reduce::Sum, &z4, {1});
    ASSERT_TRUE(z4.equalsTo(&exp4));

    x.reduceAlongDimension(nd4j::reduce::Sum, &z5, {0,2});
    ASSERT_TRUE(z5.equalsTo(&exp5));  
}

////////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, reduceAlongDimension_same_test2) {
    
    NDArray x('c', {2,3,2}, {1.5,2,3,4,5,6,7.5,8,-1,-2,-3.5,-4,}, nd4j::DataType::INT64);  

    NDArray exp1('c', {0}, {26}, nd4j::DataType::INT64);    
    NDArray exp2('c', {2,2}, {9,12,3,2}, nd4j::DataType::INT64);
    NDArray exp3('c', {3}, {18,4,4}, nd4j::DataType::INT64);
    NDArray exp4('c', {3,2}, {8,10,2,2,2,2}, nd4j::DataType::INT64);
    NDArray exp5('c', {2}, {21,5}, nd4j::DataType::INT64);
    
    NDArray z1 = x.reduceAlongDims(nd4j::reduce::Sum, {0,1,2});
    ASSERT_TRUE(z1.equalsTo(&exp1));    
    
    NDArray z2 = x.reduceAlongDims(nd4j::reduce::Sum, {1});
    ASSERT_TRUE(z2.equalsTo(&exp2));    

    NDArray z3 = x.reduceAlongDims(nd4j::reduce::Sum, {0,2});
    ASSERT_TRUE(z3.equalsTo(&exp3));    

    x.permutei({1,0,2});    // 3x2x2

    NDArray z4 = x.reduceAlongDims(nd4j::reduce::Sum, {0,1,2});    
    ASSERT_TRUE(z4.equalsTo(&exp1));

    NDArray z5 = x.reduceAlongDims(nd4j::reduce::Sum, {1});
    ASSERT_TRUE(z5.equalsTo(&exp4));

    NDArray z6 = x.reduceAlongDims(nd4j::reduce::Sum, {0,2});
    ASSERT_TRUE(z6.equalsTo(&exp5));      
}

////////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, reduceAlongDimension_bool_test1) {
    
    NDArray x('c', {2,3,2}, {0.5,2,3,-4,5,6,-7.5,8,-1,-0.5,-3.5,4}, nd4j::DataType::DOUBLE);

    NDArray z1('c', {0}, {100}, nd4j::DataType::BOOL);    
    NDArray z2('c', {2,2}, {100,100,100,100}, nd4j::DataType::BOOL);
    NDArray z3('c', {3}, {100,100,100}, nd4j::DataType::BOOL);
    NDArray z4('c', {3,2}, {100,100,100,100,100,100}, nd4j::DataType::BOOL);
    NDArray z5('c', {2}, {100,100}, nd4j::DataType::BOOL);

    NDArray exp1('c', {0}, {1}, nd4j::DataType::BOOL);    
    NDArray exp2('c', {2,2}, {1,1,0,1}, nd4j::DataType::BOOL);
    NDArray exp3('c', {3}, {1,1,1}, nd4j::DataType::BOOL);
    NDArray exp4('c', {3,2}, {1,1,1,0,1,1}, nd4j::DataType::BOOL);
    NDArray exp5('c', {2}, {1,1}, nd4j::DataType::BOOL);
    
    x.reduceAlongDimension(nd4j::reduce::IsPositive, &z1, {0,1,2});    
    ASSERT_TRUE(z1.equalsTo(&exp1));
    
    x.reduceAlongDimension(nd4j::reduce::IsPositive, &z2, {1});
    ASSERT_TRUE(z2.equalsTo(&exp2));

    x.reduceAlongDimension(nd4j::reduce::IsPositive, &z3, {0,2});
    ASSERT_TRUE(z3.equalsTo(&exp3));

    x.permutei({1,0,2});    // 3x2x2

    x.reduceAlongDimension(nd4j::reduce::IsPositive, &z1, {0,1,2});    
    ASSERT_TRUE(z1.equalsTo(&exp1));

    x.reduceAlongDimension(nd4j::reduce::IsPositive, &z4, {1});
    ASSERT_TRUE(z4.equalsTo(&exp4));

    x.reduceAlongDimension(nd4j::reduce::IsPositive, &z5, {0,2});
    ASSERT_TRUE(z5.equalsTo(&exp5));  
}

////////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, reduceAlongDimension_bool_test2) {
    
    NDArray x('c', {2,3,2}, {0.5,2,3,-4,5,6,-7.5,8,-1,-0.5,-3.5,4}, nd4j::DataType::INT32);

    NDArray exp1('c', {0}, {1}, nd4j::DataType::BOOL);    
    NDArray exp2('c', {2,2}, {1,1,0,1}, nd4j::DataType::BOOL);
    NDArray exp3('c', {3}, {1,1,1}, nd4j::DataType::BOOL);
    NDArray exp4('c', {3,2}, {0,1,1,0,1,1}, nd4j::DataType::BOOL);
    NDArray exp5('c', {2}, {1,1}, nd4j::DataType::BOOL);
    
    NDArray z1 = x.reduceAlongDims(nd4j::reduce::IsPositive, {0,1,2});
    ASSERT_TRUE(z1.equalsTo(&exp1));    
    
    NDArray z2 = x.reduceAlongDims(nd4j::reduce::IsPositive, {1});
    ASSERT_TRUE(z2.equalsTo(&exp2));    

    NDArray z3 = x.reduceAlongDims(nd4j::reduce::IsPositive, {0,2});
    ASSERT_TRUE(z3.equalsTo(&exp3));    

    x.permutei({1,0,2});    // 3x2x2

    NDArray z4 = x.reduceAlongDims(nd4j::reduce::IsPositive, {0,1,2});    
    ASSERT_TRUE(z4.equalsTo(&exp1));

    NDArray z5 = x.reduceAlongDims(nd4j::reduce::IsPositive, {1});
    ASSERT_TRUE(z5.equalsTo(&exp4));

    NDArray z6 = x.reduceAlongDims(nd4j::reduce::IsPositive, {0,2});
    ASSERT_TRUE(z6.equalsTo(&exp5));      
}

////////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, reduceAlongDimension_long_test1) {
    
    NDArray x('c', {2,3,2}, {0.5,2,3,-0,5,6,-7.5,0,-1,-0.5,-3.5,4}, nd4j::DataType::FLOAT32);

    NDArray z1('c', {0}, {100}, nd4j::DataType::INT64);    
    NDArray z2('c', {2,2}, {100,100,100,100}, nd4j::DataType::INT64);
    NDArray z3('c', {3}, {100,100,100}, nd4j::DataType::INT64);
    NDArray z4('c', {3,2}, {100,100,100,100,100,100}, nd4j::DataType::INT64);
    NDArray z5('c', {2}, {100,100}, nd4j::DataType::INT64);

    NDArray exp1('c', {0}, {2}, nd4j::DataType::INT64);    
    NDArray exp2('c', {2,2}, {0,1,0,1}, nd4j::DataType::INT64);
    NDArray exp3('c', {3}, {1,1,0}, nd4j::DataType::INT64);
    NDArray exp4('c', {3,2}, {0,1,0,1,0,0}, nd4j::DataType::INT64);
    NDArray exp5('c', {2}, {1,1}, nd4j::DataType::INT64);
    
    x.reduceAlongDimension(nd4j::reduce::CountZero, &z1, {0,1,2});    
    ASSERT_TRUE(z1.equalsTo(&exp1));
    
    x.reduceAlongDimension(nd4j::reduce::CountZero, &z2, {1});
    ASSERT_TRUE(z2.equalsTo(&exp2));

    x.reduceAlongDimension(nd4j::reduce::CountZero, &z3, {0,2});
    ASSERT_TRUE(z3.equalsTo(&exp3));

    x.permutei({1,0,2});    // 3x2x2

    x.reduceAlongDimension(nd4j::reduce::CountZero, &z1, {0,1,2});    
    ASSERT_TRUE(z1.equalsTo(&exp1));

    x.reduceAlongDimension(nd4j::reduce::CountZero, &z4, {1});
    ASSERT_TRUE(z4.equalsTo(&exp4));

    x.reduceAlongDimension(nd4j::reduce::CountZero, &z5, {0,2});
    ASSERT_TRUE(z5.equalsTo(&exp5));  
}

////////////////////////////////////////////////////////////////////////////////
TEST_F(NDArrayCudaBasicsTests, reduceAlongDimension_long_test2) {
    
    NDArray x('c', {2,3,2}, {0.5,2,3,-0,5,6,-7.5,0,-1,-0.5,-3.5,4}, nd4j::DataType::INT32);
    
    NDArray exp1('c', {0}, {4}, nd4j::DataType::INT64);    
    NDArray exp2('c', {2,2}, {1,1,0,2}, nd4j::DataType::INT64);
    NDArray exp3('c', {3}, {2,2,0}, nd4j::DataType::INT64);
    NDArray exp4('c', {3,2}, {1,1,0,2,0,0}, nd4j::DataType::INT64);
    NDArray exp5('c', {2}, {2,2}, nd4j::DataType::INT64);
    
    NDArray z1 = x.reduceAlongDims(nd4j::reduce::CountZero, {0,1,2});
    ASSERT_TRUE(z1.equalsTo(&exp1));    
    
    NDArray z2 = x.reduceAlongDims(nd4j::reduce::CountZero, {1});
    ASSERT_TRUE(z2.equalsTo(&exp2));    

    NDArray z3 = x.reduceAlongDims(nd4j::reduce::CountZero, {0,2});
    ASSERT_TRUE(z3.equalsTo(&exp3));    

    x.permutei({1,0,2});    // 3x2x2

    NDArray z4 = x.reduceAlongDims(nd4j::reduce::CountZero, {0,1,2});    
    ASSERT_TRUE(z4.equalsTo(&exp1));

    NDArray z5 = x.reduceAlongDims(nd4j::reduce::CountZero, {1});
    ASSERT_TRUE(z5.equalsTo(&exp4));

    NDArray z6 = x.reduceAlongDims(nd4j::reduce::CountZero, {0,2});
    ASSERT_TRUE(z6.equalsTo(&exp5));
}

// printCudaGlobal<double><<<1,1,0,*stream>>>(dX, 6);
//     printCudaGlobal<Nd4jLong><<<1,1,0,*stream>>>(dXShapeInfo, 8);
//     printCudaGlobal<double><<<1,1,0,*stream>>>(dZ, 2);
//     printCudaGlobal<Nd4jLong><<<1,1,0,*stream>>>(dZShapeInfo, 6);
//     printCudaGlobal<int><<<1,1,0,*stream>>>(dimension, 1);
//     printCudaGlobal<Nd4jLong><<<1,1,0,*stream>>>(tadShapeInfo, 6);
//     printCudaGlobal<Nd4jLong><<<1,1,0,*stream>>>(tadOffsets, 2);
//     cudaStreamSynchronize(*stream);  
