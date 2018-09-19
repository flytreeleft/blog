---
layout: post
title: 算法分析：分治法求解给定集合中的众数及其重数
date: 2018-09-19 21:38:34
tags:
  - 算法分析
  - 分治法
  - 众数与重数
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

给定含有n个元素的多重集合`S`，每个元素在`S`中<u>出现的次数</u>称为该元素的**重数**。多重集`S`中<u>重数最大的元素</u>称为[众数](https://zh.wikipedia.org/wiki/%E4%BC%97%E6%95%B0_(%E6%95%B0%E5%AD%A6))（**mode**）。

例如，`S={1，2，2，2，3，5}`，则，多重集`S`的众数是`2`，其重数为`3`。

> 注：众数可能存在多个。

本案例要求采用[分治法](https://zh.wikipedia.org/wiki/%E5%88%86%E6%B2%BB%E6%B3%95)求解给定集合中的众数及其重数，存在多个众数时选择第一个即可。

<!--more-->

## 求解思路

分治法求解的基本思路就是将集合分成几个小部分，依次查找每个部分中的众数，再从每个部分中取出重数最大的数，该数即为所求解的众数。

在分治求解过程中，当枢轴元素（**pivot**）所在位置的左右两侧剩余的数据量均小于`pivot`的重数时，则求解结束且所求的众数即为`pivot`的值。

## 实现代码

```c
#include<stdio.h>
#include<stdlib.h>

int g_mode; // 众数值
int g_cnt = 0; // 众数的重数值

// 优先声明相关函数定义以便于按照阅读先后顺序排列函数实现
void divide_find_mode(int data[], int start_index, int end_index);
int sort_and_find_pivot(int data[], int start_index, int end_index);
void swap_element(int data[], int index_0, int index_1);

int main(void) {
    //int data[] = {'a', 'a', 'b', 'b', 'b', '1', '2', '1'};
    int data[] = {2, 4, 7, 8, 5, 6, 5, 5, 6, 7, 1};
    //int data[] = {1, 2, 2, 2, 3, 3, 5, 6, 6, 6, 6};
    //int data[] = {1, 2, 7, 7, 3, 5};
    //int data[] = {3, 6, 7, 6, 4, 5};
    int len = sizeof(data) / sizeof(data[0]);
    divide_find_mode(data, 0, len - 1);

    printf("众数为: %d, 且其重数为: %d\n", g_mode, g_cnt);
    // 当集合元素为char类型时，使用以下方式输出结果
    //printf("众数为: %c, 且其重数为: %d\n", g_mode, g_cnt);

    return 0;
}

// 采用分治法查找集合data在指定范围（[start_index, end_index]区间）内的众数及其重数
void divide_find_mode(int data[], int start_index, int end_index) {
    int pivot_index = sort_and_find_pivot(data, start_index, end_index);

    // 从右边开始统计与pivot相等的元素个数（包括pivot本身）
    int pivot_cnt = 0;
    for (int i = start_index; i <= pivot_index; i++) {
        if (data[i] == data[pivot_index]) {
            pivot_cnt++;
        }
    }

    // 记录重数最大的元素及其重数值
    if (pivot_cnt > g_cnt) {
        g_mode = data[pivot_index];
        g_cnt = pivot_cnt;
    }

    // 若左边剩余元素数量大于当前的重数值，则继续寻找左边剩余元素（范围为[start_index, pivot_index - 1]）中的众数
    // 左边剩余元素数量 = 当前众数位置左移一位（pivot_index - 1） - 查询的开始位置序号 + 1
    // 如，数组{1, 2, 3, 4， 5}中3（其序号为2）左边剩余元素数量为2（即，2 - 1 - 0 + 1）
    if ((pivot_index - 1) - start_index + 1 > pivot_cnt) {
        divide_find_mode(data, start_index, pivot_index - 1);
    }
    // 若右边剩余元素数量大于当前的重数值，则继续寻找右边剩余元素（范围为[pivot_index + 1, end_index]）中的众数
    // 右边剩余元素数量 = 查询的结束位置序号 - 当前众数位置右移一位（pivot_index + 1） + 1
    // 如，数组{1, 2, 3, 4， 5}中3（其序号为2）右边剩余元素数量为2（即，4 - (2 + 1) + 1）
    if (end_index - (pivot_index + 1) + 1 > pivot_cnt) {
        divide_find_mode(data, pivot_index + 1, end_index);
    }
}

// 在集合data的指定范围（[start_index, end_index]区间）内选择一个枢轴元素（pivot）并进行排序，
// 以确保在该范围内pivot左边的元素均小于或等于pivot，而右边的则均大于pivot
int sort_and_find_pivot(int data[], int start_index, int end_index) {
    // 取开始位置的元素作为枢轴元素
    int pivot = data[start_index];

    int left_index = start_index;
    int right_index = end_index;
    // 从两边向中间推进以调整元素位置，最终确保左边的元素小于或等于pivot，而右边的元素大于pivot
    while (left_index < right_index) {
        // 从右边向中间推进直到遇到小于或等于pivot的元素
        while (left_index < right_index && data[right_index] > pivot) {
            right_index--;
        }
        // 从左边向中间推进直到遇到大于pivot的元素
        while (left_index < right_index && data[left_index] <= pivot) {
            left_index++;
        }
        // 将 左边大于pivot的元素 与 右边小于或等于pivot的元素 交换位置
        swap_element(data, left_index, right_index);
    }
    // Note：在排序过程中start_index位置的元素是不会变动位置的（其必然等于pivot），
    // 而left_index位置的元素为最后一个小于或等于pivot的元素，
    // 这时交换二者位置后，便可确保pivot左边的元素均小于或等于pivot了
    swap_element(data, start_index, left_index);

    return left_index;
}

// 交换集合data中两个指定元素位置（index_0与index_1）的数据
void swap_element(int data[], int index_0, int index_1) {
    int temp = data[index_0];

    data[index_0] = data[index_1];
    data[index_1] = temp;
}
```

以上代码应该能够很容易看懂。这里主要强调以下几点：
- 对外传播的代码应该尽量降低阅读者的理解难度以及**时间成本**
- 变量名、函数名一定要能够清晰、准确地传达出其所代表的东西以及其职能，不要简单使用`i`、`j`等无意义的名称，更不要使用语义不清甚至是错误的单词
- 函数实现代码一般按照调用先后顺序和重要性进行排列以便于阅读并突出关键实现等
- 注释主要用于阐明流程、算法机制和原理、特殊代码技巧以及在调整或改进时需特别注意的事项等内容，切记不要对代码本身进行说明，说明也不要**又臭又长**。PS：本文为了能让刚入门的开发者看懂并阐述算法机制和过程，所以，注释写得比较详细，在实际开发中可以默认视为阅读者具备相关的算法基础，从而无需再对算法进行注释说明
- 一般通过`sizeof(data) / sizeof(data[0])`方式动态计算数组长度

## 实现改进

上面的代码在调用`sort_and_find_pivot()`后存在一次遍历以获得`pivot`的重数（`pivot_cnt`），但实际上在`sort_and_find_pivot()`排序过程中已经存在等值比较，在这个时候是可以顺便得到`pivot`的重数的，只是限于C语言的函数只能返回一个值的约束而无法同时返回其重数。不过，C语言提供结构体类型，故而，可以通过在`sort_and_find_pivot()`后返回结构体的方式以避免不必要的遍历。

以下为改进后的代码：

```c
#include<stdio.h>
#include<stdlib.h>

typedef struct _Mode {
    int value; // 众数值
    int count; // 众数重复次数，即重数
    int index; // 主要用于在查找pivot时记录其最终位置
} Mode;

// 优先声明相关函数定义以便于按照阅读先后顺序排列函数实现
Mode divide_find_mode(int data[], int start_index, int end_index);
Mode sort_and_find_pivot(int data[], int start_index, int end_index);
void swap_element(int data[], int index_0, int index_1);
int compare_mode(Mode mode_0, Mode mode_1);

int main(void) {
    //int data[] = {'a', 'a', 'b', 'b', 'b', '1', '2', '1'};
    int data[] = {2, 4, 7, 8, 5, 6, 5, 5, 6, 7, 1};
    //int data[] = {1, 2, 2, 2, 3, 3, 5, 6, 6, 6, 6};
    //int data[] = {1, 2, 7, 7, 3, 5};
    //int data[] = {3, 6, 7, 6, 4, 5};
    int len = sizeof(data) / sizeof(data[0]);

    Mode mode = divide_find_mode(data, 0, len - 1);

    printf("众数为: %d, 且其重数为: %d\n", mode.value, mode.count);
    // 当集合元素为char类型时，使用以下方式输出结果
    //printf("众数为: %c, 且其重数为: %d\n", mode.value, mode.count);

    return 0;
}

// 采用分治法查找集合data在指定范围（[start_index, end_index]区间）内的众数及其重数
Mode divide_find_mode(int data[], int start_index, int end_index) {
    Mode pivot = sort_and_find_pivot(data, start_index, end_index);

    Mode mode = pivot;
    // 若左边剩余元素数量大于当前的重数值，则继续寻找左边剩余元素（范围为[start_index, pivot.index - 1]）中的众数
    // 左边剩余元素数量 = 当前众数位置左移一位（pivot.index - 1） - 查询的开始位置序号 + 1
    // 如，数组{1, 2, 3, 4， 5}中3（其序号为2）左边剩余元素数量为2（即，2 - 1 - 0 + 1）
    if ((pivot.index - 1) - start_index + 1 > pivot.count) {
        Mode m = divide_find_mode(data, start_index, pivot.index - 1);
        mode = compare_mode(m, mode) > 0 ? m : mode;
    }
    // 若右边剩余元素数量大于当前的重数值，则继续寻找右边剩余元素（范围为[pivot.index + 1, end_index]）中的众数
    // 右边剩余元素数量 = 查询的结束位置序号 - 当前众数位置右移一位（pivot.index + 1） + 1
    // 如，数组{1, 2, 3, 4， 5}中3（其序号为2）右边剩余元素数量为2（即，4 - (2 + 1) + 1）
    if (end_index - (pivot.index + 1) + 1 > pivot.count) {
        Mode m = divide_find_mode(data, pivot.index + 1, end_index);
        mode = compare_mode(m, mode) > 0 ? m : mode;
    }

    return mode;
}

// 在集合data的指定范围（[start_index, end_index]区间）内选择一个枢轴元素（pivot）并进行排序，
// 以确保在该范围内pivot左边的元素均小于或等于pivot，而右边的则均大于pivot
Mode sort_and_find_pivot(int data[], int start_index, int end_index) {
    int left_index = start_index;
    int right_index = end_index;

    Mode pivot = {
        // 取开始位置的元素作为枢轴元素
        .value = data[start_index],
        // 当只有一个元素时，则不会进行排序，也就不会有等值判断，故，count将始终为1
        .count = left_index == right_index ? 1 : 0
    };

    // 从两边向中间推进以调整元素位置，最终确保左边的元素小于或等于pivot，而右边的元素大于pivot
    while (left_index < right_index) {
        // 从右边向中间推进直到遇到小于或等于pivot的元素
        while (left_index < right_index && data[right_index] > pivot.value) {
            right_index--;
        }
        if (left_index < right_index && data[right_index] == pivot.value) {
            pivot.count++;
        }

        // 从左边向中间推进直到遇到大于pivot的元素
        while (left_index < right_index && data[left_index] <= pivot.value) {
            if (data[left_index] == pivot.value) {
                pivot.count++;
            }
            left_index++;
        }
        // 将 左边大于pivot的元素 与 右边小于或等于pivot的元素 交换位置
        swap_element(data, left_index, right_index);
    }
    // Note：在排序过程中start_index位置的元素是不会变动位置的（其必然等于pivot），
    // 而left_index位置的元素为最后一个小于或等于pivot的元素，
    // 这时交换二者位置后，便可确保pivot左边的元素均小于或等于pivot了
    swap_element(data, start_index, left_index);

    pivot.index = left_index;

    return pivot;
}

// 交换集合data中两个指定元素位置（index_0与index_1）的数据
void swap_element(int data[], int index_0, int index_1) {
    if (index_0 == index_1) {
        return;
    }

    int temp = data[index_0];

    data[index_0] = data[index_1];
    data[index_1] = temp;
}

int compare_mode(Mode mode_0, Mode mode_1) {
    return mode_0.count - mode_1.count;
}
```

这里主要强调以下几点：
- 在离调用最近的位置处声明变量，避免变量声明位置与第一次使用位置相隔太远
- 结构体数据的初始化采用[(ANSI) C99](https://gcc.gnu.org/onlinedocs/gcc/Designated-Inits.html)方式以便于阅读，如，`struct point p = { .y = yvalue, .x = xvalue };`
