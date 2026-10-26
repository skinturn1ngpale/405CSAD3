#include <gtest/gtest.h>

#include <limits>

#include "../math_operations.h"

TEST(MathOperationsTest, BasicAddition) {
	EXPECT_EQ(add(2, 3), 5);
}

TEST(MathOperationsTest, NegativeNumbers) {
	EXPECT_EQ(add(-2, -3), -5);
	EXPECT_EQ(add(-2, 3), 1);
}

TEST(MathOperationsTest, Zero) {
	EXPECT_EQ(add(0, 0), 0);
	EXPECT_EQ(add(0, 42), 42);
	EXPECT_EQ(add(-42, 0), -42);
}

TEST(MathOperationsTest, LargeValues) {
	const int max = std::numeric_limits<int>::max();
	const int min = std::numeric_limits<int>::min();

	EXPECT_EQ(add(max - 1, 1), max);
	EXPECT_EQ(add(min + 1, -1), min);
}
