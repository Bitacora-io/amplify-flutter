/*
 * Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore_plugin_interface/amplify_datastore_plugin_interface.dart';
import 'package:flutter/foundation.dart';

class DocumentInputs {
  // Upper document input: ($id: ID!)
  final String upper;
  // Lower document input: (id: $id)
  final String lower;
  const DocumentInputs(this.upper, this.lower);
}

class GraphQLRequestFactory {
  GraphQLRequestFactory._();

  static final GraphQLRequestFactory _instance = GraphQLRequestFactory._();

  static GraphQLRequestFactory get instance => _instance;

  String _getName(ModelSchema schema, GraphQLRequestOperation operation) {
    // schema has been validated & schema.pluralName is non-nullable
    return operation == GraphQLRequestOperation.list
        ? schema.pluralName!
        : schema.name;
  }

  String _getModelType(ModelFieldTypeEnum val) {
    switch (val) {
      case ModelFieldTypeEnum.string:
        return "String";
      case ModelFieldTypeEnum.model:
        return "ID";
      case ModelFieldTypeEnum.int:
        return "Int";
      case ModelFieldTypeEnum.double:
        return "Float";
      case ModelFieldTypeEnum.dateTime:
        return "AWSDateTime";
      case ModelFieldTypeEnum.time:
        return "AWSTime";
      case ModelFieldTypeEnum.timestamp:
        return "AWSTimestamp";
      // TODO: Expand type support: enumeration, collection
      default:
        return "Error: unsupported type!";
    }
  }

  String _getFieldsFromModelType(
      ModelSchema schema, GraphQLRequestOperation operation) {
    // schema has been validated & schema.fields is non-nullable
    String fields = schema.fields!.entries
        .map((entry) => entry.value.association == null ? entry.key : '')
        .toList()
        .join(' ');

    if (operation == GraphQLRequestOperation.list) {
      fields = 'items { $fields } nextToken';
    }

    return fields;
  }

  ModelSchema _getAndValidateSchema(
      ModelType modelType, GraphQLRequestOperation operation) {
    ModelProviderInterface? provider = AmplifyAPI.instance.getModelProvider();

    if (provider == null) {
      throw ApiException('No modelProvider found',
          recoverySuggestion:
              'Pass in a modelProvider instance while instantiating APIPlugin');
    }

    ModelSchema schema = provider.modelSchemas.firstWhere(
        (elem) => elem.name == modelType.modelName(),
        orElse: () => throw ApiException(
            'No schema found for the ModelType provided',
            recoverySuggestion:
                'Pass in a valid modelProvider instance while instantiating APIPlugin or provide a valid ModelType'));

    if (schema.fields == null) {
      throw ApiException('Schema found does not have a fields property',
          recoverySuggestion:
              'Pass in a valid modelProvider instance while instantiating APIPlugin');
    }

    if (operation == GraphQLRequestOperation.list &&
        schema.pluralName == null) {
      throw ApiException('No schema name found',
          recoverySuggestion:
              'Pass in a valid modelProvider instance while instantiating APIPlugin or provide a valid ModelType');
    }

    return schema;
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  DocumentInputs _buildDocumentInputs(
      ModelSchema schema, GraphQLRequestOperation operation) {
    String upperOutput = '';
    String lowerOutput = '';
    List<String> upperList = [];
    List<String> lowerList = [];

    String modelName = schema.name;

    // build inputs based on request operation
    switch (operation) {
      case GraphQLRequestOperation.get:
        upperOutput = r"($id: ID!)";
        lowerOutput = r"(id: $id)";
        break;
      case GraphQLRequestOperation.list:
        upperOutput =
            "(\$filter: Model${modelName}FilterInput, \$limit: Int, \$nextToken: String)";
        lowerOutput =
            r"(filter: $filter, limit: $limit, nextToken: $nextToken)";
        break;
      case GraphQLRequestOperation.create:
      case GraphQLRequestOperation.update:
      case GraphQLRequestOperation.delete:
        String operationValue = _capitalize(describeEnum(operation));

        upperOutput =
            "(\$input: ${operationValue}${modelName}Input!, \$condition:  Model${modelName}ConditionInput)";
        lowerOutput = r"(input: $input, condition: $condition)";
        break;
      default:
        throw ApiException('GraphQL Request Operation is currently unsupported',
            recoverySuggestion: 'please use a supported GraphQL operation');
    }

    return DocumentInputs(upperOutput, lowerOutput);
  }

/**
   *  Example: 
   *    query getBlog($id: ID!, $content: String) { getBlog(id: $id, content: $content) { id name createdAt } }
  */
  GraphQLRequest<T> buildRequest<T extends Model>(
      {required ModelType modelType,
      Model? model,
      required GraphQLRequestType requestType,
      required GraphQLRequestOperation requestOperation,
      required Map<String, dynamic> variables}) {
    // retrieve schema from ModelType and validate required properties
    ModelSchema schema = _getAndValidateSchema(modelType, requestOperation);

    // e.g. "Blog" or "Blogs"
    String name = _getName(schema, requestOperation);
    // e.g. "query" or "mutation"
    String requestTypeVal = describeEnum(requestType);
    // e.g. "get" or "list"
    String requestOperationVal = describeEnum(requestOperation);
    // e.g. "{upper: "($id: ID!)", lower: "(id: $id)"}"
    DocumentInputs documentInputs =
        _buildDocumentInputs(schema, requestOperation);
    // e.g. "id name createdAt" - fields to retrieve
    String fields = _getFieldsFromModelType(schema, requestOperation);
    // e.g. "getBlog"
    String requestName = "$requestOperationVal$name";
    // e.g. query getBlog($id: ID!, $content: String) { getBlog(id: $id, content: $content) { id name createdAt } }
    String document =
        '''$requestTypeVal $requestName${documentInputs.upper} { $requestName${documentInputs.lower} { $fields } }''';
    // e.g "listBlogs"
    String decodePath = requestName;

    return GraphQLRequest<T>(
        document: document,
        variables: variables,
        modelType: modelType,
        decodePath: decodePath);
  }

  Map<String, dynamic> buildVariables(
      {int? limit, String? nextToken, QueryPredicate? queryPredicate}) {
    return <String, dynamic>{
      'filter': null, // TODO: handle query predicates
      'limit': limit,
      'nextToken': nextToken
    };
  }
}
