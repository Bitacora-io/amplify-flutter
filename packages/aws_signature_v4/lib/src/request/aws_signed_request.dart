// Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';

/// {@template aws_signature_v4.aws_sig_v4_signed_request}
/// A signed [AWSStreamedHttpRequest].
/// {@endtemplate}
class AWSSignedRequest extends AWSStreamedHttpRequest {
  /// The canonical request for this request.
  final CanonicalRequest canonicalRequest;

  /// The signature for [canonicalRequest].
  final String signature;

  /// @{macro aws_signature_v4.aws_sig_v4_signed_request}
  AWSSignedRequest({
    required this.canonicalRequest,
    required this.signature,
    required AWSHttpMethod method,
    required String host,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    required Stream<List<int>> body,
    int? contentLength,
  }) : super.raw(
          method: method,
          host: host,
          path: path,
          queryParameters: queryParameters,
          headers: headers,
          body: body,
          contentLength: contentLength,
        );
}
