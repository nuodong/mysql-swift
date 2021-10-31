#ifndef __CMYSQL_SHIM_H__
#define __CMYSQL_SHIM_H__

#ifdef __APPLE__
#include <mysql.h>
#else
#include <mysql/mysql.h>
#endif


#if LIBMYSQL_VERSION_ID >= 80000
typedef int my_bool;
#endif

#endif

