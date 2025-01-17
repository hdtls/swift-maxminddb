//===----------------------------------------------------------------------===//
//
// This source file is part of the Netbot open source project
//
// Copyright (c) 2021 Junfeng Zhang. and the Netbot project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
// See CONTRIBUTORS.txt for the list of Netbot project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_implementationOnly import CMaxMindDB

#if os(Windows)
  import struct WinSDK.sockaddr
#elseif canImport(Darwin)
  import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
  #if canImport(Glibc)
    import Glibc
  #elseif canImport(Musl)
    import Musl
  #elseif canImport(Android)
    import Android
  #else
  #error("Unable to identify your C library.")
  #endif
#else
  #error("Unable to identify your C library.")
#endif

/// A reference to a MaxMind database object (`MMDB *`).
///
final public class MaxMindDB {

  public enum Mode: UInt32, Sendable {
    case mmap = 1
    case mask = 7
  }

  public var version: String {
    .init(cString: MMDB_lib_version())
  }

  private let db: UnsafeMutablePointer<MMDB_s>

  /// Create and open `MaxMindDB` from a file at given path in either mmap or mask mode.
  ///
  /// - Parameters:
  ///   - file: The path to the file to load the database from.
  ///   - mode: The mode use to open database.
  public init(file: String, mode: Mode) throws {
    db = UnsafeMutablePointer.allocate(capacity: MemoryLayout<MMDB_s>.size)
    db.initialize(to: .init())

    let status = file.withCString {
      MMDB_open($0, mode.rawValue, db)
    }

    guard status == MMDB_SUCCESS else {
      throw MaxMindDBError.unknowError(CMaxMindDBError(errorCode: status))
    }
  }

  /// Create and open `MaxMindDB` from a file at given path in mmap mode.
  ///
  /// - Parameter file: The path to the file to load the database from.
  @available(*, deprecated, renamed: "MaxMindDB.init(file:mode:)")
  public convenience init(file: String) throws {
    try self.init(file: file, mode: .mmap)
  }

  /// Looks up an IP address that is passed in.
  ///
  /// If you have already resolved an address you can call `lookup(sockaddr:)` directly, rather than resolving the address twice.
  /// - Parameter ipAddress: IP address to lookup.
  /// - Returns: Lookup result if found else nil.
  public func lookup(ipAddress: String) throws -> Any? {
    var gaiError: Int32 = 0
    var error: Int32 = MMDB_SUCCESS

    let result = ipAddress.withCString {
      MMDB_lookup_string(db, $0, &gaiError, &error)
    }

    guard gaiError == 0 else {
      throw MaxMindDBError.gaiError(GetaddrinfoError(errorCode: gaiError))
    }

    guard error == MMDB_SUCCESS else {
      throw MaxMindDBError.unknowError(CMaxMindDBError(errorCode: error))
    }

    return try parseJSONValue(from: result)
  }

  /// Looks up an sockaddr.
  /// - Parameter sockaddr: The sockaddr to lookup.
  /// - Returns: Lookup result if found else nil.
  public func lookup(sockaddr: sockaddr) throws -> Any? {
    var error: Int32 = MMDB_SUCCESS

    let result = withUnsafePointer(to: sockaddr) {
      MMDB_lookup_sockaddr(db, $0, &error)
    }

    guard error == MMDB_SUCCESS else {
      throw MaxMindDBError.unknowError(CMaxMindDBError(errorCode: error))
    }

    return try parseJSONValue(from: result)
  }

  private func parseJSONValue(from result: MMDB_lookup_result_s) throws -> Any? {
    var mutableValue = result

    guard mutableValue.found_entry else {
      return nil
    }

    var error = MMDB_SUCCESS
    var dataListPtr: UnsafeMutablePointer<MMDB_entry_data_list_s>?

    error = MMDB_get_entry_data_list(&mutableValue.entry, &dataListPtr)

    guard error == MMDB_SUCCESS else {
      MMDB_free_entry_data_list(dataListPtr)
      throw MaxMindDBError.unknowError(CMaxMindDBError(errorCode: error))
    }

    defer {
      MMDB_free_entry_data_list(dataListPtr)
    }

    var pointee = dataListPtr?.pointee
    return try parseJSONValue0(from: &pointee)
  }

  private func parseJSONValue0(from data: inout MMDB_entry_data_list_s!) throws -> Any? {
    guard data != nil else {
      return nil
    }

    switch Int32(data.entry_data.type) {
    case MMDB_DATA_TYPE_ARRAY:
      var array: [Any] = []
      var size = data.entry_data.data_size

      data = data.next?.pointee
      while data != nil && size > 0 {
        if let jsonValue = try parseJSONValue0(from: &data) {
          array.append(jsonValue)
        }
        size -= 1
        guard size > 0 else {
          continue
        }
        data = data.next?.pointee
      }
      return array
    case MMDB_DATA_TYPE_BOOLEAN:
      return data.entry_data.boolean
    case MMDB_DATA_TYPE_DOUBLE:
      return data.entry_data.double_value
    case MMDB_DATA_TYPE_FLOAT:
      return data.entry_data.float_value
    case MMDB_DATA_TYPE_MAP:
      var dictionary: [String: Any] = [:]
      var size = data.entry_data.data_size

      data = data.next?.pointee
      while data != nil && size > 0 {
        let key = try parseJSONString(from: data)

        data = data.next?.pointee
        if let jsonValue = try parseJSONValue0(from: &data) {
          dictionary[key] = jsonValue
        }
        size -= 1
        guard size > 0 else {
          continue
        }
        data = data.next?.pointee
      }
      return dictionary
    case MMDB_DATA_TYPE_INT32:
      return data.entry_data.int32
    case MMDB_DATA_TYPE_UINT16:
      return data.entry_data.uint16
    case MMDB_DATA_TYPE_UINT32:
      return data.entry_data.uint32
    case MMDB_DATA_TYPE_UINT64:
      return data.entry_data.uint64
    case MMDB_DATA_TYPE_UINT128:
      return data.entry_data
    case MMDB_DATA_TYPE_UTF8_STRING:
      return try parseJSONString(from: data)
    default:
      assertionFailure("Unsupported MaxMindDB raw data type \(data.entry_data.type).")
      return nil
    }
  }

  private func parseJSONString(from value: MMDB_entry_data_list_s) throws -> String {
    // Ignore other useless keys
    guard value.entry_data.type == MMDB_DATA_TYPE_UTF8_STRING else {
      throw MaxMindDBError.unknowError(.init(errorCode: MMDB_INVALID_DATA_ERROR))
    }

    guard let cString = value.entry_data.utf8_string else {
      throw MaxMindDBError.unknowError(.init(errorCode: MMDB_OUT_OF_MEMORY_ERROR))
    }

    return String(String(cString: cString).prefix(Int(value.entry_data.data_size)))
  }

  deinit {
    MMDB_close(db)
  }
}

// MaxMindDB is publicly immutable and we do not internally mutate it after initialisation.
// It is therefore Sendable.
extension MaxMindDB: @unchecked Sendable {}
