---
title: How to write a good unit test
seo_title: how-to-write-a-good-unit-test
date: 2023-11-22 21:33:29
tags: [Python,Coding]
categories: [Program]
---

# What

A unit test is a type of software testing that focuses on verifying the correctness of **individual units** of a software system. A unit, in this context, refers to the **smallest** testable part of a system, typically a method.

A unit test can verify different behavioural aspects of the system under test, but most likely it will fall into one of the following two categories: *state-based* or *interaction-based*. Verifying that the system under test produces correct results, or that its resulting state is correct, is called **state-based** unit testing, while verifying that it properly invokes certain methods is called **interaction-based** unit testing.

# Why

Writing unit tests is important for several reasons:

1. **Detecting Bugs Early**: Unit tests help identify bugs or issues in the code early in the development process. By writing tests that cover different scenarios and edge cases, you can catch and address problems before they propagate to other parts of the codebase or reach production.
2. **Facilitating Refactoring**: Unit tests provide a safety net when refactoring code. They allow you to modify or restructure the codebase with confidence, knowing that if the tests pass, the intended functionality is maintained. Without unit tests, refactoring becomes more challenging and error-prone.
3. **Improving Code Quality**: Writing unit tests encourages writing modular, decoupled, and testable code. It promotes good software engineering practices such as the single responsibility principle, separation of concerns, and dependency injection. This leads to cleaner, more maintainable code.
4. **Enhancing Collaboration**: Unit tests serve as documentation of the expected behaviour of the code. They provide insights into how the code should be used and its intended functionality. Tests also facilitate collaboration among team members, allowing them to understand and contribute to the codebase more effectively.
5. **Enabling Continuous Integration and Delivery**: Unit tests play a crucial role in setting up automated continuous integration and delivery (CI/CD) pipelines. They provide a mechanism for automatically verifying the correctness of code changes, ensuring that new features or bug fixes don't introduce regressions.
6. **Boosting Confidence and Reducing Debugging Time**: Having a comprehensive suite of passing unit tests builds confidence in the stability and correctness of the codebase. When a test fails, it provides a clear indication of which part of the code is causing the issue, thereby reducing the time and effort required for debugging.

By investing time in writing unit tests, you can improve the overall quality, maintainability, and reliability of your code. They provide a foundation for more robust and confident software development processes.

# How

1. **Use Descriptive Test Names**: *Don’t be afraid of long, descriptive names*. Give your tests meaningful and descriptive names that clearly indicate what aspect of the code is being tested. This makes it easier to understand the purpose of each test and helps in quickly identifying the cause of failures.
   [Component/Feature]_[Scenario]_[ExpectedResult]
2. **Test One Thing at a Time**: Each unit test should focus on testing a specific behaviour or functionality of a single unit (e.g., a function or a method). Avoid testing multiple behaviours in a single test case, as it makes it harder to identify the cause of failures.
3. **Keep Tests Independent and isolated**: Unit tests should be independent of each other, meaning that the outcome of one test should not affect the outcome of another test. This helps in isolating issues and makes it easier to pinpoint failures.
4. **Cover Happy Path First & Test Edge Cases**: Choose test cases that cover critical user interactions, edge cases, and important user workflows. Focus on areas that are prone to errors or have a high impact on user experience. The happy path usually is the simplest test to write and it **illustrates how to use the code **being tested.
5. **Follow the Arrange-Act-Assert (AAA) pattern:** Structure your test code using the AAA pattern. Arrange the necessary preconditions, perform the actions or interactions with the UI, and then assert the expected outcomes or results.
6. **Write Tests Before Fixing Bugs: **Once you’ve found the code that isn’t working as it should, consider writing the test that reproduces this bug. Fixing it by debugging the test in isolation from the rest of the application code will be much quicker. You’ll leave an excellent regression test to spot this bug in the future. And you’ll know that you’ve fixed it properly when the test that previously failed starts passing.


# Questions

- Balancing the time spent on writing unit tests and delivering software?
- **Set realistic expectations:** Set realistic expectations for both the delivery timeline and the time required for writing unit tests. This involves estimating the effort involved in writing tests and factoring it into your project planning.
- **Prioritize critical functionality:** Prioritize the critical functionality or high-risk areas of your software for writing unit tests. Focus on areas that are prone to errors, have complex logic, or have a high impact on the overall system. This ensures that important components are thoroughly tested while minimizing the time spent on testing less critical parts.
- **Refactor and maintain tests:** Regularly review and refactor your unit tests to ensure they remain up to date and maintainable. Eliminate redundant or unnecessary tests, update tests when requirements change, and ensure that tests align with the current behavior of the software.
- **Continuous improvement:** Continuously assess and improve your testing process. Gather feedback from the team, analyze the effectiveness of your tests, and identify areas for improvement. This iterative approach helps refine your testing strategy and optimize the time spent on writing tests.
- Any other questions?
