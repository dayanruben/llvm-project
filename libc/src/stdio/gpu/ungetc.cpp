//===-- Implementation of ungetc ------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "src/stdio/ungetc.h"

#include "file.h"
#include "hdr/types/FILE.h"
#include "src/__support/common.h"

namespace LIBC_NAMESPACE_DECL {

LLVM_LIBC_FUNCTION(int, ungetc, (int c, ::FILE *stream)) {
  int ret;
  rpc::Client::Port port = rpc::client.open<LIBC_UNGETC>();
  port.send_and_recv(
      [=](rpc::Buffer *buffer, uint32_t) {
        buffer->data[0] = c;
        buffer->data[1] = file::from_stream(stream);
      },
      [&](rpc::Buffer *buffer, uint32_t) {
        ret = static_cast<int>(buffer->data[0]);
      });
  port.close();
  return ret;
}

} // namespace LIBC_NAMESPACE_DECL
