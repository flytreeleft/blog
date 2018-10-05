---
layout: post
title: 算法分析：求解最大子段和
date: 2018-10-05 11:19:00
tags:
  - 动态规划
  - 最大子段和
  - 分治法
  - 穷举法
categories:
  - 算法分析
---

> 算法分析系列文章中的代码可被任何人无偿使用于任何场景且无需注明来源也不必在使用前征得本文作者同意。
>
> 算法分析系列文章旨在传播准确、完整、简洁、易懂、规范的代码实现，并传授基本的编程思想和良好的编码习惯与技巧。
>
> 若文章中的代码存在问题或逻辑错误，请通过邮件等形式（见文章结尾）告知于本文作者以便及时修正错误或改进代码。
>
> PS：若为转载该文章，请务必注明来源，本站点欢迎大家转载。

## 问题描述

给定一个**整数**（正负数不限）序列 $a_1, a_2, a_3, ..., a_n$ ，从该序列中选取任意**相邻**的一段求和（简称为「子段和」），求解该序列的**最大子段和**。注：若整个序列的所有元素均为负数，则其最大子段和固定为0。

例如，序列`[64, -24, 88, -39, -54, 16]`的最大子段和为`128`（= `64 + (-24) + 88`）。
<!--more-->

## 求解方案

### 穷举法

穷举法就是从 $a_0$ 开始依次计算 $$a_0, a_0 + a_1, a_0 + a_1 + a_2, a_0 + a_1 + ... + a_n$$ 并取其中的最大值，再从 $a_1$ 开始依次计算 $$a_1, a_1 + a_2, a_1 + a_2 + ... + a_n$$ 并取其中的最大值，以此往复，直到 $a_n$ 为止，并取每次计算过程中的最大值，得到的最终结果即为所求。

该穷举过程用代码实现即为：

```c
typedef struct _SubseqSum {
    int value; // 序列区间求和后的值
    int start; // 求和区间的开始位置
    int end; // 求和区间的结束位置
} SubseqSum;

SubseqSum max_subseq_sum_force(int seq[], int seq_len) {
    SubseqSum max_sum = { .value = 0, .start = 0, .end = 0 };

    int max_sum_value = 0;
    for (int i = 0; i < seq_len; i++) {
        for (int j = i; j < seq_len; j++) {
            // 计算从i到j这个区间的和
            int sum_value = 0;
            for (int k = i; k <= j; k++) {
                sum_value += seq[k];
            }
            // 当i到j的区间的和大于当前已记录的最大子段和时，更新该最大子段和为该区间的和
            if (sum_value > max_sum_value) {
                max_sum_value = sum_value;

                // 更新最大子段和的结果及其求和区间
                max_sum.value = max_sum_value;
                max_sum.start = i;
                max_sum.end = j;
            }
        }
    }
    return max_sum;
}
```

注意：
- 这里定义了结构体`SubseqSum`用于同时记录子段和及其求和区间，可便于对最终结果进行人工复查以验证代码的正确性
- 在`for`、`if ... else ...`等分支中即使仅有一行代码，甚至没有代码（如，`while (true) {}`），也不要省略花括号（`{}`），这是避免代码混乱、提升代码可读性和准确性的前提
- 通过指针类型的参数来获取函数内部的过程数据（如，`int max_subseq_sum(int seq[], int seq_len, int &begin, int &end) {...}`）的方式不是一种良好的编码习惯。虽然，许多编程语言的函数不支持返回多值，但通过结构体等方式可以更好地达到目的（甚至好于返回多值），最终的代码也会更易阅读和理解

本例用到了三层循环，其时间复杂度为 $O(n^3)$ 。但仔细分析后可以发现，在第三层循环中，从 $i$ 到 $j$ 区间的和会被重复计算多次，即，存在计算序列 $$a_i, a_i + a_{i+1}, a_i + a_{i+1} + a_{i+2}, a_i + a_{i+1} + ... + a_{j-1} + a_j$$ ，而实际上， $$a_i + ... + a_{j-1}$$ 已经被计算过了，没有必要再重复计算，若将其存放在变量 $tmp$ 中（即， $$tmp = a_i + a_{i+1} + ... + a_{j-1}$$ ），则计算 $$a_i + a_{i+1} + ... + a_{j-1} + a_j$$ 的值，等效于计算 $$tmp + a_j$$ 的值。

按照以上思路，可将上面的穷举实现改进为如下代码（时间复杂度为 $O(n^2)$ ）：

```c
typedef struct _SubseqSum {
    int value; // 序列区间求和后的值
    int start; // 求和区间的开始位置
    int end; // 求和区间的结束位置
} SubseqSum;

SubseqSum max_subseq_sum_force_adv(int seq[], int seq_len) {
    SubseqSum max_sum = { .value = 0, .start = 0, .end = 0 };

    int max_sum_value = 0;
    for (int i = 0; i < seq_len; i++) {
        // 通过sum_value记录从i到j-1这个区间的和，
        // 当求解i到j区间的和时，其便等效于sum_value+seq[j]
        int sum_value = 0;
        for (int j = i; j < seq_len; j++) {
            sum_value += seq[j];

            if (sum_value > max_sum_value) {
                max_sum_value = sum_value;

                // 更新最大子段和的结果及其求和区间
                max_sum.value = max_sum_value;
                max_sum.start = i;
                max_sum.end = j;
            }
        }
    }
    return max_sum;
}
```

### 分治法

> 分治法，即，把一个复杂的问题分成两个或更多的相同或相似的子问题，直到最后子问题可以简单的直接求解，原问题的解即子问题的解的合并。（引用自「维基百科」）

通过分治法的思想，可以将序列 $$a_1, a_2, ..., a_n$$ **等分**为两部分，即， $$a_1, a_2, ..., a_{\frac{n}{2}}$$ （称为**左子序列**） 与 $$a_{\frac{n}{2}+1}, a_{\frac{n}{2}+2}, ..., a_n$$ （称为**右子序列**） 两个子序列，再分别求解这两个子序列的最大子段和。最终原序列的最大子段和的求解便存在以下情况：
- 原序列的最大子段和等于左子序列的最大子段和
- 原序列的最大子段和等于右子序列的最大子段和
- 原序列的最大子段和为 $$\sum_{k=i}^{j} a_k$$ ，其中， $$1 \leq i \leq \frac{n}{2}, \frac{n}{2}+1 \leq j \leq n$$

前两种情况通过递归可以得到结果，而对于第三种情况，可以从 $\frac{n}{2}$ 和 $\frac{n}{2}+1$ 开始分别向左右两边求和，即，定义如下表达式：

$$
\begin{align}
s1 &= \max_{1 \leq i \leq \frac{n}{2}} \bigg\{ \sum_{k=i}^{\frac{n}{2}} a_k \bigg\} & \Leftrightarrow s1 &= \max\{ a_{\frac{n}{2}}, a_{\frac{n}{2}} + a_{\frac{n}{2}-1}, ..., a_{\frac{n}{2}} + a_{\frac{n}{2}-1} + ... + a_2 + a_1 \} \\
s2 &= \max_{\frac{n}{2}+1 \leq j \leq n} \bigg\{ \sum_{k=j}^{n} a_k \bigg\} & \Leftrightarrow s1 &= \max\{ a_{\frac{n}{2}+1}, a_{\frac{n}{2}+1} + a_{\frac{n}{2}+2}, ..., a_{\frac{n}{2}+1} + a_{\frac{n}{2}+2} + ... + a_{n-1} + a_n \}
\end{align}
$$

则 $$s1+s2$$ 即为第三种情况的最优解。

根据以上分析可编写其实现代码为（时间复杂度为 $O(n\log n)$ ）：

```c
typedef struct _SubseqSum {
    int value; // 序列区间求和后的值
    int start; // 求和区间的开始位置
    int end; // 求和区间的结束位置
} SubseqSum;

int max(int num0, int num1) {
    return num0 > num1 ? num0 : num1;
}

SubseqSum max_subseq_sum_divide(int seq[], int left, int right) {
    if (left == right) {
        return (SubseqSum) {
            .value = max(0, seq[left]),
            .start = left,
            .end = left
        };
    }

    int center = (left + right) / 2;
    // 计算左边区间的最大子段和
    SubseqSum left_max_sum = max_subseq_sum_divide(seq, left, center);
    // 计算右边区间的最大子段和
    SubseqSum right_max_sum = max_subseq_sum_divide(seq, center + 1, right);
    // 计算从中间位置向左右区间的最大子段和
    SubseqSum center_max_sum = max_subseq_sum_divide_for_center(seq, center, left, right);

    // 三个部分的最大结果即为所求的最大子段和
    SubseqSum max_sum = center_max_sum;
    if(max_sum.value < left_max_sum.value) {
        max_sum = left_max_sum;
    }
    if(max_sum.value < right_max_sum.value) {
        max_sum = right_max_sum;
    }
    return max_sum;
}

// 从中间位置开始对该位置左右两边子段进行求和
SubseqSum max_subseq_sum_divide_for_center(int seq[], int center, int left, int right) {
    SubseqSum max_sum = { .value = 0, .start = center, .end = center };

    // [left, ..., center, center + 1, ..., right]
    //           <-- i       j -->

    // 先从center开始向左推进以计算左边子段求和的最大值：
    // - i记录的是左边求和区间的左边界（右边界为center）
    // - 只有求和结果（left_sum_value）大于0才会推进
    int left_sum_value = 0;
    int left_max_sum_value = 0;
    for (int i = center; i >= left; i--) {
        left_sum_value += seq[i];

        if (left_sum_value > left_max_sum_value) {
            left_max_sum_value = left_sum_value;
            max_sum.start = i;
        }
    }
    // 再从center+1开始向右推进以计算右边子段求和的最大值：
    // - j记录的是右边求和区间的右边界（左边界为center+1）
    // - 只有求和结果（right_sum_value）大于0才会推进
    int right_sum_value = 0;
    int right_max_sum_value = 0;
    for(int j = center + 1; j <= right; j++) {
        right_sum_value += seq[j];

        if(right_sum_value > right_max_sum_value) {
            right_max_sum_value = right_sum_value;
            max_sum.end = j;
        }
    }

    // 最后所求的子段和为左右两个子段的 最大求和值 之和
    int max_sum_value = left_max_sum_value + right_max_sum_value;

    max_sum.value = max_sum_value;
    // 子段求和未向左推进（向左求和的结果依然为0）但向右推进（向右求和的结果大于0）了，
    // 则表示求和区间应该从右边开始
    if (left_max_sum_value == 0 && right_max_sum_value > 0) {
        max_sum.start = center + 1;
    }
    // 子段求和未向右推进（向右求和的结果依然为0）但向左推进（向左求和的结果大于0）了，
    // 则表示求和区间应该从左边开始
    if (right_max_sum_value == 0 && left_max_sum_value > 0) {
        max_sum.end = center;
    }
    // 而若向左/向右均没有推进，则保持原地不动
    if (left_max_sum_value == 0 && right_max_sum_value == 0) {
        max_sum.start = max_sum.end = center;
    }

    return max_sum;
}
```

注意：
- 在实现代码中将上面提到的第三种情况提取出来以便对该特例进行独立分析，也避免了对前面的主过程的阅读和分析造成的干扰
- 在`max_subseq_sum_divide_for_center`的最后需要对求和区间的起始位置进行修正，具体内容见代码注释

### 动态规划法

在应用该方法之前，先来看看其数学的推导过程。

假设存在序列 $a_1, a_2, a_3, ..., a_n$ ，记 $b_j$ 表示该序列从 $1$ 到 $j$ 的区间内的最大子段和，则其可用如下公式表示：

$$
b_j = \max_{1 \leq i \leq j} \bigg\{ \sum_{k=i}^{j} a_k \bigg\}, 1 \leq j \leq n
$$

也就是以下等式成立：

$$
\begin{align}
b_1 &= a_1 \\
b_2 &= \max\{ a_1 + a_2, a_2 \} \\
b_3 &= \max\{ a_1 + a_2 + a_3, a_2 + a_3, a_3 \}
\end{align}
$$

因此，求解整个序列的最大子段和 $F(n)$ 的数学公式即为：

$$
F(n) = \max_{1 \leq i \leq j \leq n} \bigg\{ \sum_{k=i}^{j} a_k \bigg\} = \max_{1 \leq j \leq n} \Bigg\{ \max_{1 \leq i \leq j} \bigg\{ \sum_{k=i}^{j} a_k \bigg\} \Bigg\} = \max_{1 \leq j \leq n}\{ b_j \}
$$

也就是说，要求解整个序列的最大子段和，可以转化为计算从 $1$ 到 $n$ 的区间内的 $b_j$ （ $1 \leq j \leq n$ ） 的最大值。

而 $b_j$ 可以用递归表达式表示为：

$$
b_j = \max\{ b_{j - 1} + a_j, a_j \}, 1 \leq j \leq n
$$

但是，当 $$b_{j-1}$$ 小于等于0时，无论 $$a_j$$ 为正还是负，最终 $$b_{j-1}+a_j$$ 都将小于 $$a_j$$ ，这时将有 $$b_j=a_j$$ 成立，因此，最终 $$b_j$$ 可表示为：

$$
b_j = \begin{cases}
b_{j - 1} + a_j,    & b_{j - 1} > 0 \\
a_j,                & b_{j - 1} \leq 0
\end{cases}
, 1 \leq j \leq n
$$

以上推导过程需要仔细阅读和分析，在完全掌握该推导过程后，便可很容易编写出对应的求解代码（时间复杂度为 $O(n)$ ），即：

```c
#define MAX_SEQ_LEN 1000
typedef struct _SubseqSum {
    int value; // 序列区间求和后的值
    int start; // 求和区间的开始位置
    int end; // 求和区间的结束位置
} SubseqSum;

int max(int num0, int num1) {
    return num0 > num1 ? num0 : num1;
}

SubseqSum max_subseq_sum_dynamic_programming(int seq[], int seq_len) {
    // 求和序列：存放子段求和的中间结果，开始元素为传入序列的第0项
    int seq_sum[MAX_SEQ_LEN] = { seq[0] };
    SubseqSum max_sum = { .value = max(0, seq_sum[0]), .start = 0, .end = 0 };

    int max_sum_value = 0;
    int expected_sum_start = 0;
    for(int j = 1; j < seq_len; j++) {
        // 向左看，若前面已计算的子段和大于0，则加上当前项后，可能会得到更大的子段和，
        // 即对应公式中的“b[j] = b[j-1] + a[j]”分支
        if (seq_sum[j - 1] > 0) {
            seq_sum[j] = seq_sum[j - 1] + seq[j];
        }
        // 而若前面已计算的子段和小于0，则丢弃该结果，从当前位置开始重新计算子段和，
        // 即对应公式中的“b[j] = a[j]”分支
        else {
            seq_sum[j] = seq[j];
            // 但新的子段和不一定大于当前已得到的最大子段和，
            // 故，需临时存放该新子段的开始位置，待最大子段和被更新后再更新其所在的子段区间
            expected_sum_start = j;
        }

        // 这里取公式中的“b[j]”的最大值
        if (seq_sum[j] > max_sum_value) {
            max_sum_value = seq_sum[j];

            // 应用新的子段和，并更新该子段的开始和结束位置
            max_sum.value = max_sum_value;
            max_sum.start = expected_sum_start;
            max_sum.end = j;
        }
    }
    return max_sum;
}
```

## 参考

- [最大子段和问题总结](https://www.cnblogs.com/youxin/p/3405268.html)：涉及穷举法、分治法、动态规划法及改进
- [动态规划之最大子段和](https://blog.csdn.net/Netown_Ethereal/article/details/23865151)：对动态规划法的公式讲解较为详细
- [最大子段和(分治与动态规划典例)](https://blog.csdn.net/ccDLlyy/article/details/52244504)：对分治法讲解较为详细

## 附录

以下为完整的各方案代码，并包含性能测试：

```c
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h> // for gettimeofday()
#include <time.h> // for time()

#define MAX_SEQ_LEN 1000
typedef struct _SubseqSum {
    int value; // 序列区间求和后的值
    int start; // 求和区间的开始位置
    int end; // 求和区间的结束位置
} SubseqSum;

double current_timestamp();
int max(int num0, int num1);
void init_random_sequence(int seq[], int len);
void print_sequence(int seq[], int len);
int sum_subseq(int seq[], int start, int end);

SubseqSum max_subseq_sum_force(int seq[], int seq_len);
SubseqSum max_subseq_sum_force_adv(int seq[], int seq_len);
SubseqSum max_subseq_sum_divide(int seq[], int left, int right);
SubseqSum max_subseq_sum_divide_for_center(int seq[], int center, int left, int right);
SubseqSum max_subseq_sum_dynamic_programming(int seq[], int seq_len);

int main(int argc, char *argv[]) {
    int seq_len = 50;
    int seq[MAX_SEQ_LEN];
    init_random_sequence(seq, seq_len);
    // int seq[] = {-31, 95, 62, -45, 13, 31, -77, 22, 94, -65, -67, 50, -66, 28, -98, -34, -97, -66, -84, 87, 32, -28, 43, -75, -64, 24, 88, 39, -54, -16, 89, 82, -81, 45, 61, -62, -51, -4, -41, -32, -21, -37, 32, 63, -44, -39, -30, -19, 71, 77};
    // int seq[] = {-5, 11, -4, 13, -4, -2};
    // int seq[] = {0, 0, 0, 0, 0, 0}; // 不同方法得到的求和区间会不同
    // int seq_len = sizeof(seq) / sizeof(seq[0]);
    SubseqSum max_sum;
    double start_time, end_time;

    print_sequence(seq, seq_len);
    printf("\n以上序列的最大子段和为:\n");

    start_time = current_timestamp();
    max_sum = max_subseq_sum_force(seq, seq_len);
    end_time = current_timestamp();
    printf("- 穷举算法        : %d (求和区间: [%d, %d] +=>> %d), 耗时: %f毫秒\n"
                , max_sum.value
                , max_sum.start, max_sum.end
                , sum_subseq(seq, max_sum.start, max_sum.end)
                , end_time - start_time);

    start_time = current_timestamp();
    max_sum = max_subseq_sum_force_adv(seq, seq_len);
    end_time = current_timestamp();
    printf("- 穷举算法(改进版): %d (求和区间: [%d, %d] +=>> %d), 耗时: %f毫秒\n"
                , max_sum.value
                , max_sum.start, max_sum.end
                , sum_subseq(seq, max_sum.start, max_sum.end)
                , end_time - start_time);

    start_time = current_timestamp();
    max_sum = max_subseq_sum_divide(seq, 0, seq_len - 1);
    end_time = current_timestamp();
    printf("- 分治算法        : %d (求和区间: [%d, %d] +=>> %d), 耗时: %f毫秒\n"
                , max_sum.value
                , max_sum.start, max_sum.end
                , sum_subseq(seq, max_sum.start, max_sum.end)
                , end_time - start_time);

    start_time = current_timestamp();
    max_sum = max_subseq_sum_dynamic_programming(seq, seq_len);
    end_time = current_timestamp();
    printf("- 动态规划算法    : %d (求和区间: [%d, %d] +=>> %d), 耗时: %f毫秒\n"
                , max_sum.value
                , max_sum.start, max_sum.end
                , sum_subseq(seq, max_sum.start, max_sum.end)
                , end_time - start_time);

    return 0;
}

// 穷举（蛮力）法求解
SubseqSum max_subseq_sum_force(int seq[], int seq_len) {
    SubseqSum max_sum = { .value = 0, .start = 0, .end = 0 };

    int max_sum_value = 0;
    for (int i = 0; i < seq_len; i++) {
        for (int j = i; j < seq_len; j++) {
            // 计算从i到j这个区间的和
            int sum_value = 0;
            for (int k = i; k <= j; k++) {
                sum_value += seq[k];
            }
            // 当i到j的区间的和大于当前已记录的最大子段和时，更新该最大子段和为该区间的和
            if (sum_value > max_sum_value) {
                max_sum_value = sum_value;

                // 更新最大子段和的结果及其求和区间
                max_sum.value = max_sum_value;
                max_sum.start = i;
                max_sum.end = j;
            }
        }
    }
    return max_sum;
}

// 穷举法（改进版）求解
SubseqSum max_subseq_sum_force_adv(int seq[], int seq_len) {
    SubseqSum max_sum = { .value = 0, .start = 0, .end = 0 };

    int max_sum_value = 0;
    for (int i = 0; i < seq_len; i++) {
        // 通过sum_value记录从i到j-1这个区间的和，
        // 当求解i到j区间的和时，其便等效于sum_value+seq[j]
        int sum_value = 0;
        for (int j = i; j < seq_len; j++) {
            sum_value += seq[j];

            if (sum_value > max_sum_value) {
                max_sum_value = sum_value;

                // 更新最大子段和的结果及其求和区间
                max_sum.value = max_sum_value;
                max_sum.start = i;
                max_sum.end = j;
            }
        }
    }
    return max_sum;
}

// 分治法求解
SubseqSum max_subseq_sum_divide(int seq[], int left, int right) {
    if (left == right) {
        return (SubseqSum) {
            .value = max(0, seq[left]),
            .start = left,
            .end = left
        };
    }

    int center = (left + right) / 2;
    // 计算左边区间的最大子段和
    SubseqSum left_max_sum = max_subseq_sum_divide(seq, left, center);
    // 计算右边区间的最大子段和
    SubseqSum right_max_sum = max_subseq_sum_divide(seq, center + 1, right);
    // 计算从中间位置向左右区间的最大子段和
    SubseqSum center_max_sum = max_subseq_sum_divide_for_center(seq, center, left, right);

    // 三个部分的最大结果即为所求的最大子段和
    SubseqSum max_sum = center_max_sum;
    if(max_sum.value < left_max_sum.value) {
        max_sum = left_max_sum;
    }
    if(max_sum.value < right_max_sum.value) {
        max_sum = right_max_sum;
    }
    return max_sum;
}

// 分治法求解：从中间位置开始对该位置左右两边子段进行求和
SubseqSum max_subseq_sum_divide_for_center(int seq[], int center, int left, int right) {
    SubseqSum max_sum = { .value = 0, .start = center, .end = center };

    // [left, ..., center, center + 1, ..., right]
    //           <-- i       j -->

    // 先从center开始向左推进以计算左边子段求和的最大值：
    // - i记录的是左边求和区间的左边界（右边界为center）
    // - 只有求和结果（left_sum_value）大于0才会推进
    int left_sum_value = 0;
    int left_max_sum_value = 0;
    for (int i = center; i >= left; i--) {
        left_sum_value += seq[i];

        if (left_sum_value > left_max_sum_value) {
            left_max_sum_value = left_sum_value;
            max_sum.start = i;
        }
    }
    // 再从center+1开始向右推进以计算右边子段求和的最大值：
    // - j记录的是右边求和区间的右边界（左边界为center+1）
    // - 只有求和结果（right_sum_value）大于0才会推进
    int right_sum_value = 0;
    int right_max_sum_value = 0;
    for(int j = center + 1; j <= right; j++) {
        right_sum_value += seq[j];

        if(right_sum_value > right_max_sum_value) {
            right_max_sum_value = right_sum_value;
            max_sum.end = j;
        }
    }

    // 最后所求的子段和为左右两个子段的 最大求和值 之和
    int max_sum_value = left_max_sum_value + right_max_sum_value;

    max_sum.value = max_sum_value;
    // 子段求和未向左推进（向左求和的结果依然为0）但向右推进（向右求和的结果大于0）了，
    // 则表示求和区间应该从右边开始
    if (left_max_sum_value == 0 && right_max_sum_value > 0) {
        max_sum.start = center + 1;
    }
    // 子段求和未向右推进（向右求和的结果依然为0）但向左推进（向左求和的结果大于0）了，
    // 则表示求和区间应该从左边开始
    if (right_max_sum_value == 0 && left_max_sum_value > 0) {
        max_sum.end = center;
    }
    // 而若向左/向右均没有推进，则保持原地不动
    if (left_max_sum_value == 0 && right_max_sum_value == 0) {
        max_sum.start = max_sum.end = center;
    }

    return max_sum;
}

// 动态规划法求解
SubseqSum max_subseq_sum_dynamic_programming(int seq[], int seq_len) {
    // 求和序列：存放子段求和的中间结果，开始元素为传入序列的第0项
    int seq_sum[MAX_SEQ_LEN] = { seq[0] };
    SubseqSum max_sum = { .value = max(0, seq_sum[0]), .start = 0, .end = 0 };

    int max_sum_value = 0;
    int expected_sum_start = 0;
    for(int j = 1; j < seq_len; j++) {
        // 向左看，若前面已计算的子段和大于0，则加上当前项后，可能会得到更大的子段和，
        // 即对应公式中的“b[j] = b[j-1] + a[j]”分支
        if (seq_sum[j - 1] > 0) {
            seq_sum[j] = seq_sum[j - 1] + seq[j];
        }
        // 而若前面已计算的子段和小于0，则丢弃该结果，从当前位置开始重新计算子段和，
        // 即对应公式中的“b[j] = a[j]”分支
        else {
            seq_sum[j] = seq[j];
            // 但新的子段和不一定大于当前已得到的最大子段和，
            // 故，需临时存放该新子段的开始位置，待最大子段和被更新后再更新其所在的子段区间
            expected_sum_start = j;
        }

        // 这里取公式中的“b[j]”的最大值
        if (seq_sum[j] > max_sum_value) {
            max_sum_value = seq_sum[j];

            // 应用新的子段和，并更新该子段的开始和结束位置
            max_sum.value = max_sum_value;
            max_sum.start = expected_sum_start;
            max_sum.end = j;
        }
    }
    return max_sum;
}

int max(int num0, int num1) {
    return num0 > num1 ? num0 : num1;
}

// 获取当前系统时间的毫秒值
double current_timestamp() {
    struct timeval te;
    gettimeofday(&te, NULL);

    double msec = te.tv_sec * 1000.0 + (te.tv_usec / 1000.0);
    return msec;
}

void init_random_sequence(int seq[], int len) {
    // https://www.geeksforgeeks.org/rand-and-srand-in-ccpp/
    srand(time(0));

    for (int i = 0; i < len; i++) {
        // 取0-100之间的数并随机产生正负
        seq[i] = (int) (rand() * 1.0 / RAND_MAX * 100) * (rand() % 2 == 0 ? 1 : -1);
    }
}

void print_sequence(int seq[], int len) {
    int columns = 10;
    for (int i = 0; i < len; i++) {
        printf("%3d: %3d, ", i, seq[i]);

        if ((i + 1) % columns == 0 && i < len - 1) {
            printf("\n");
        }
    }
}

int sum_subseq(int seq[], int start, int end) {
    int sum = 0;
    for (int i = (start < end ? start : end); i <= (end > start ? end : start); i++) {
        sum += seq[i];
    }
    return sum;
}
```
