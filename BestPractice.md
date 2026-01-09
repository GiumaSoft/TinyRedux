# BestPractice

<!--@START_MENU_TOKEN@-->Summary<!--@END_MENU_TOKEN@-->

## Overview

<!--@START_MENU_TOKEN@-->Text<!--@END_MENU_TOKEN@-->

## Topics

### <!--@START_MENU_TOKEN@-->Group<!--@END_MENU_TOKEN@-->

- ``Properties sort order``

@Wrapped 

open let
open var
public let
public var
let
var
private let
private var

static open let
static open var
static public let
static public var
static let 
static var
static private let
static private var


- ``Namespace``



- ``View structure``

    struct CustomView {
      // properties
    }
    
    extension CustomView: View {
      // view content segregation
      var body: some View {
        Content()
      }
    }

    extension CustomView {
      private struct Content {
        // properties
      }
    }
    
    extension CustomView.Content {
      // view builders
      var body: some View {
          // Content view
      }
    }

Fragment View can have parameter   
