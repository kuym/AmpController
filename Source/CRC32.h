#ifndef _CRC32_H_
#define _CRC32_H_

void			CRC32HashIncremental(unsigned int& remainder, unsigned char const* message, int length);
unsigned int	CRC32Hash(unsigned char const* message, int length);

#endif //_CRC32_H_
