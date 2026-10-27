cmake_minimum_required(VERSION 3.15)
project(KlondikeCLI VERSION 1.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(SOURCE_FILES Deck.cpp
        Deck.h
        Card.cpp
        Card.h
        Game.cpp
        Game.h
        main.cpp
        Stack.cpp
        Stack.h
        Board.cpp
        Board.h)

include_directories(.)

add_executable(KlondikeCLI ${SOURCE_FILES})

install(TARGETS KlondikeCLI RUNTIME DESTINATION .)
