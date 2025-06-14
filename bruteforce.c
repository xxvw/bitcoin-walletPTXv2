#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <CL/cl.h>

#define MAX_WORDS 2048
#define MAX_WORD_LENGTH 32
#define MAX_SOURCE_SIZE 100000

// OpenCLの変数
cl_context context;
cl_command_queue command_queue;
cl_program program;
cl_kernel kernel;
cl_mem wordlist_buffer;
cl_mem wordlist_size_buffer;
cl_mem target_hash_buffer;
cl_mem result_buffer;
cl_mem found_buffer;

// シードフレーズ
char wordlist[MAX_WORDS][MAX_WORD_LENGTH];
int wordlist_size = 0;

// OpenCLの初期化
int init_opencl() {
    cl_int ret;
    cl_platform_id platform_id;
    cl_device_id device_id;
    cl_uint ret_num_devices;
    cl_uint ret_num_platforms;

    // プラットフォームの取得
    ret = clGetPlatformIDs(1, &platform_id, &ret_num_platforms);
    if (ret != CL_SUCCESS) {
        printf("プラットフォームの取得に失敗しました\n");
        return -1;
    }

    // GPUデバイスの取得
    ret = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_GPU, 1, &device_id, &ret_num_devices);
    if (ret != CL_SUCCESS) {
        printf("GPUデバイスの取得に失敗しました\n");
        return -1;
    }

    // コンテキストの作成
    context = clCreateContext(NULL, 1, &device_id, NULL, NULL, &ret);
    if (ret != CL_SUCCESS) {
        printf("コンテキストの作成に失敗しました\n");
        return -1;
    }

    // コマンドキューの作成
    command_queue = clCreateCommandQueue(context, device_id, 0, &ret);
    if (ret != CL_SUCCESS) {
        printf("コマンドキューの作成に失敗しました\n");
        return -1;
    }

    // カーネルソースの読み込み
    FILE *fp;
    char *source_str;
    size_t source_size;

    fp = fopen("bruteforce.cl", "r");
    if (!fp) {
        printf("カーネルファイルの読み込みに失敗しました\n");
        return -1;
    }
    source_str = (char*)malloc(MAX_SOURCE_SIZE);
    source_size = fread(source_str, 1, MAX_SOURCE_SIZE, fp);
    fclose(fp);

    // プログラムの作成
    program = clCreateProgramWithSource(context, 1, (const char **)&source_str, (const size_t *)&source_size, &ret);
    if (ret != CL_SUCCESS) {
        printf("プログラムの作成に失敗しました\n");
        return -1;
    }

    // プログラムのビルド
    ret = clBuildProgram(program, 1, &device_id, NULL, NULL, NULL);
    if (ret != CL_SUCCESS) {
        printf("プログラムのビルドに失敗しました\n");
        return -1;
    }

    // カーネルの作成
    kernel = clCreateKernel(program, "bruteforce_kernel", &ret);
    if (ret != CL_SUCCESS) {
        printf("カーネルの作成に失敗しました\n");
        return -1;
    }

    return 0;
}

// 単語リストを読み込む
void load_wordlist() {
    char word[MAX_WORD_LENGTH];
    while (fgets(word, sizeof(word), stdin) && wordlist_size < MAX_WORDS) {
        word[strcspn(word, "\n")] = 0;
        strncpy(wordlist[wordlist_size], word, MAX_WORD_LENGTH - 1);
        wordlist[wordlist_size][MAX_WORD_LENGTH - 1] = '\0';
        wordlist_size++;
    }
}

// 総当たり処理のメイン
void bruteforce_seed(const char* target_hash, int max_words) {
    cl_int ret;
    size_t global_work_size = 1000000; // 並列処理の数
    char result[1024] = {0};
    int found = 0;

    // バッファの作成
    wordlist_buffer = clCreateBuffer(context, CL_MEM_READ_ONLY, sizeof(wordlist), wordlist, &ret);
    wordlist_size_buffer = clCreateBuffer(context, CL_MEM_READ_ONLY, sizeof(int), &wordlist_size, &ret);
    target_hash_buffer = clCreateBuffer(context, CL_MEM_READ_ONLY, strlen(target_hash) + 1, (void*)target_hash, &ret);
    result_buffer = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(result), NULL, &ret);
    found_buffer = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(int), NULL, &ret);

    // カーネル引数の設定
    clSetKernelArg(kernel, 0, sizeof(cl_mem), (void *)&wordlist_buffer);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), (void *)&wordlist_size_buffer);
    clSetKernelArg(kernel, 2, sizeof(cl_mem), (void *)&target_hash_buffer);
    clSetKernelArg(kernel, 3, sizeof(cl_mem), (void *)&result_buffer);
    clSetKernelArg(kernel, 4, sizeof(cl_mem), (void *)&found_buffer);

    // カーネルの実行
    ret = clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL, &global_work_size, NULL, 0, NULL, NULL);
    if (ret != CL_SUCCESS) {
        printf("カーネルの実行に失敗しました\n");
        return;
    }

    // 結果の読み取り
    ret = clEnqueueReadBuffer(command_queue, result_buffer, CL_TRUE, 0, sizeof(result), result, 0, NULL, NULL);
    ret = clEnqueueReadBuffer(command_queue, found_buffer, CL_TRUE, 0, sizeof(int), &found, 0, NULL, NULL);

    if (found) {
        printf("%s\n", result);
    }

    // バッファの解放
    clReleaseMemObject(wordlist_buffer);
    clReleaseMemObject(wordlist_size_buffer);
    clReleaseMemObject(target_hash_buffer);
    clReleaseMemObject(result_buffer);
    clReleaseMemObject(found_buffer);
}

// メイン関数
int main(int argc, char** argv) {
    if (argc != 2) {
        printf("使用方法: %s <ターゲットハッシュ>\n", argv[0]);
        return 1;
    }

    // OpenCLの初期化
    if (init_opencl() != 0) {
        printf("OpenCLの初期化に失敗しました\n");
        return 1;
    }

    // 単語リストを読み込む
    load_wordlist();
    fprintf(stderr, "読み込んだ単語数: %d\n", wordlist_size);

    // 総当たり処理の実行
    bruteforce_seed(argv[1], 12);

    // OpenCLのクリーンアップ
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseCommandQueue(command_queue);
    clReleaseContext(context);

    return 0;
} 