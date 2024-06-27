cmake_minimum_required(VERSION 3.25)


enable_language(OBJC)
enable_language(CXX)
enable_language(C)

# Add Metal support to CMake.
# See: https://dpogue.ca/articles/cmake-metal.html
set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH};${CMAKE_CURRENT_LIST_DIR}/CMake-MetalShaderSupport/cmake")
include(CheckLanguage)
include(MetalShaderSupport)
enable_language(Metal)

set(CMAKE_CXX_STANDARD 11)

# Find necessary libraries.
find_library(LIB_COCOA Cocoa)
find_library(LIB_METAL Metal)
find_library(LIB_QUARTZCORE QuartzCore)
set(LIBRARIES ${LIB_COCOA} ${LIB_METAL} ${LIB_QUARTZCORE})

set(CMAKE_BUILD_TYPE MinSizeRel)
project(Metal_Demo)

file(GLOB SOURCES "src/*.cpp" "src/*.c" "src/*.m")
add_executable(MetalDemo MACOSX_BUNDLE ${SOURCES})
target_include_directories(MetalDemo PRIVATE "include")
target_link_libraries(MetalDemo ${LIBRARIES})

# Add Metal shaders to the project.
file(GLOB SHADERS "metal/*.metal")
add_metal_shader_library(MetalShaderLibrary STANDARD macos-metal2.1 ${SHADERS})
target_embed_metal_shader_libraries(MetalDemo MetalShaderLibrary)
target_include_directories(MetalShaderLibrary PRIVATE "include")

# Copy assets to the built app bundle.
file(GLOB_RECURSE ASSETS "assets/*")
add_custom_command(TARGET MetalDemo POST_BUILD
        DEPENDS ${ASSETS}
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_SOURCE_DIR}/assets
        $<TARGET_BUNDLE_CONTENT_DIR:MetalDemo>/Resources/assets
        COMMENT "Copying assets to the app bundle"
)

# UPX compression to shrink executable size.
find_program(UPX upx)
if (UPX)
    message(STATUS "📦 — UPX found in: \n\t${UPX}")
    message(STATUS "📦 — UPX will be used to compress your game further in the `Compress` target.")

    set(GAME_FILE "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/MetalDemo${CMAKE_EXECUTABLE_SUFFIX}")
    set(UPX_FILE "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/MinoGame.upx${CMAKE_EXECUTABLE_SUFFIX}")

    add_custom_command(
            OUTPUT ${UPX_FILE}
            COMMAND ${CMAKE_COMMAND} -E rm -f ${UPX_FILE}
            COMMAND ${UPX} --ultra-brute -o${UPX_FILE} $<TARGET_FILE:MetalDemo>
            DEPENDS MetalDemo
    )
    add_custom_target(Compress
            DEPENDS MetalDemo
            DEPENDS ${UPX_FILE}
    )

    add_dependencies(Compress MetalDemo)

else ()
    message(STATUS "⚠️ — Could not find UPX. No compression feature available.")
endif ()

# Print sources as a sanity check.
string(REPLACE ";" "\n\t" SOURCES_LIST "${SOURCES}")
message(STATUS "🕹️ — Game sources to compile:\n\t${SOURCES_LIST}")
string(REPLACE ";" "\n\t" SHADERS_LIST "${SHADERS}")
message(STATUS "🕹️ — Game shaders to compile:\n\t${SHADERS_LIST}")