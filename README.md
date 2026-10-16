# Retail Inventory Tracking System

## Project Overview

This project simulates a simplified retail inventory-tracking system. You are provided with:

- A set of **Stores**
- A set of **Brands**
- A set of **Products**
- A large CSV file containing **1,000,000 tracking events**
- A basic importer that reads the CSV and creates `TrackingEvent` records

Your goal is to improve the system, modify one of its key features, and then add a new feature.

You are encouraged to:
- Refactor existing code
- Introduce new endpoints or views
- Improve performance, clarity, and maintainability

There is no single "correct" solution — but there are many poor ones. We want to see how **you** design and implement a real-world improvement inside a Rails application.

## Setup

This app is a standard Rails 7.1 / Ruby 3.2 project backed by PostgreSQL.

### Prerequisites

- **Ruby**: `3.2.2`
- **Rails**: `~> 7.1.6`
- **PostgreSQL**: 13+ recommended

You can use **rbenv**, **rvm**, or **asdf** to install the correct Ruby version.

#### Installing Ruby with rbenv
```bash
# Install Ruby 3.2.2
rbenv install 3.2.2

# Set it locally for this project
rbenv local 3.2.2
```

### Installation
```bash
# Install dependencies
bundle install

# Set up the database
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

### Importing Tracking Events

To import the million-row CSV file:
```bash
bin/rails tracking_events:import
```

## Objectives

### First Objective: Price Tracking

Currently, the system only tracks if inventory is present via `TrackingEvent`. We want to add a way to track price. An inventory check and price check are separate and can occur without the other happening.

### Second Objective: Alert System

Build an alert system that creates an alert to the brand if a store has two "no inventory" events in a row for the same product based on event_time. There doesn't need to be a big UI for this—just a basic index and show page like the rest of the app.

### Third Objective: Performance Improvements

Improve the app's overall performance. This can be done as you work on the first and second objectives or after completing them.

## Technology Stack

- **Ruby**: 3.2.2
- **Rails**: 7.1.6
- **Database**: PostgreSQL 13+

## Evaluation Criteria

You will be evaluated on:
- Code quality and organization
- Database design decisions
- Performance optimizations
- Ability to explain your thinking and decision making

Feel free to make reasonable assumptions where requirements are ambiguous—just document them in your code or a separate notes file.

## Time Expectation

This project should take approximately [2-3 hours] to complete. Focus on demonstrating your problem-solving approach rather than achieving perfection. AI is allowed on this project. 

## Submission

Please submit:
- A link or invite to your Git repository (GitHub, GitLab, etc.)
- A brief README or notes document explaining your key decisions
- Any instructions needed to run your solution
