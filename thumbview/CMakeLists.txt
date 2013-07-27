set (PKGNAME libsnap)
set (PKGNAME_ LIBSNAP)
set (GETTEXT_PACKAGE "snap-photobooth")
set (${PKGNAME_}_VERSION 0.1)
# increase when you broke the API

set (${PKGNAME_}_SOVERSION 0)
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

add_library (
    ${PKGNAME}  SHARED 
    cheese-thumbnail.c
    cheese-thumb-view.c
    cheese-fileutil.c
    eog-thumb-nav.c
)

if(BUILD_STATIC MATCHES "Yes")
ADD_LIBRARY(${PKGNAME}-static STATIC ${VALA_C})
# The library target "foo" already has a default OUTPUT_NAME of "foo", so we don't need to change it.

# The library target "foo-static" has a default OUTPUT_NAME of "foo-static", so change it.

SET_TARGET_PROPERTIES(${PKGNAME}-static PROPERTIES OUTPUT_NAME ${PKGNAME})
install (TARGETS ${PKGNAME}-static DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
endif(BUILD_STATIC MATCHES "Yes")

set_target_properties (${PKGNAME} PROPERTIES
    VERSION 0.1
    SOVERSION 0)
    
install (TARGETS libsnap DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/cheese-thumb-view.h DESTINATION ${CMAKE_INSTALL_PREFIX}/include/snap/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/eog-thumb-nav.h DESTINATION ${CMAKE_INSTALL_PREFIX}/include/snap/)
