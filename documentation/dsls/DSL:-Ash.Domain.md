<!--
This file was generated by Spark. Do not edit it by hand.
-->
# DSL: Ash.Domain.Dsl



## domain
General domain configuration



### Examples
```
domain do
  description """
  Resources related to the flux capacitor.
  """
end

```




### Options

| Name | Type | Default | Docs |
|------|------|---------|------|
| [`description`](#domain-description){: #domain-description } | `String.t` |  | A description for the domain. |






## resources
List the resources of this domain

### Nested DSLs
 * [resource](#resources-resource)
   * define
   * define_calculation


### Examples
```
resources do
  resource MyApp.Tweet
  resource MyApp.Comment
end

```




### Options

| Name | Type | Default | Docs |
|------|------|---------|------|
| [`allow`](#resources-allow){: #resources-allow } | `mfa` |  | Support a dynamic resource list by providing a callback that checks whether or not the resource should be allowed. |
| [`allow_unregistered?`](#resources-allow_unregistered?){: #resources-allow_unregistered? } | `boolean` | `false` | Whether the domain will support only registered entries or not. |



## resources.resource
```elixir
resource resource
```


A resource present in the domain

### Nested DSLs
 * [define](#resources-resource-define)
 * [define_calculation](#resources-resource-define_calculation)


### Examples
```
resource Foo
```



### Arguments

| Name | Type | Default | Docs |
|------|------|---------|------|
| [`resource`](#resources-resource-resource){: #resources-resource-resource .spark-required} | `module` |  |  |



## resources.resource.define
```elixir
define name
```


Defines a function with the corresponding name and arguments. See the [code interface guide](/documentation/topics/code-interface.md) for more.




### Examples
```
define :get_user_by_id, User, action: :get_by_id, args: [:id], get?: true
```



### Arguments

| Name | Type | Default | Docs |
|------|------|---------|------|
| [`name`](#resources-resource-define-name){: #resources-resource-define-name .spark-required} | `atom` |  | The name of the function that will be defined |
### Options

| Name | Type | Default | Docs |
|------|------|---------|------|
| [`action`](#resources-resource-define-action){: #resources-resource-define-action } | `atom` |  | The name of the action that will be called. Defaults to the same name as the function. |
| [`args`](#resources-resource-define-args){: #resources-resource-define-args } | `list(atom \| {:optional, atom})` |  | Map specific arguments to named inputs. Can provide any argument/attributes that the action allows. |
| [`not_found_error?`](#resources-resource-define-not_found_error?){: #resources-resource-define-not_found_error? } | `boolean` | `true` | If the action or interface is configured with `get?: true`, this determines whether or not an error is raised or `nil` is returned. |
| [`get?`](#resources-resource-define-get?){: #resources-resource-define-get? } | `boolean` |  | Expects to only receive a single result from a read action, and returns a single result instead of a list. Ignored for other action types. |
| [`get_by`](#resources-resource-define-get_by){: #resources-resource-define-get_by } | `atom \| list(atom)` |  | Takes a list of fields and adds those fields as arguments, which will then be used to filter. Sets `get?` to true automatically. Ignored for non-read actions. |
| [`get_by_identity`](#resources-resource-define-get_by_identity){: #resources-resource-define-get_by_identity } | `atom` |  | Only relevant for read actions. Takes an identity, and gets its field list, performing the same logic as `get_by` once it has the list of fields. |





### Introspection

Target: `Ash.Resource.Interface`

## resources.resource.define_calculation
```elixir
define_calculation name
```


Defines a function with the corresponding name and arguments, that evaluates a calculation. Use `:_record` to take an instance of a record. See the [code interface guide](/documentation/topics/code-interface.md) for more.




### Examples
```
define_calculation :referral_link, User, args: [:id]
```

```
define_calculation :referral_link, User, args: [{:arg, :id}, {:ref, :id}]
```



### Arguments

| Name | Type | Default | Docs |
|------|------|---------|------|
| [`name`](#resources-resource-define_calculation-name){: #resources-resource-define_calculation-name .spark-required} | `atom` |  | The name of the function that will be defined |
### Options

| Name | Type | Default | Docs |
|------|------|---------|------|
| [`calculation`](#resources-resource-define_calculation-calculation){: #resources-resource-define_calculation-calculation } | `atom` |  | The name of the calculation that will be evaluated. Defaults to the same name as the function. |
| [`args`](#resources-resource-define_calculation-args){: #resources-resource-define_calculation-args } | `any` | `[]` | Supply field or argument values referenced by the calculation, in the form of :name, `{:arg, :name}` and/or `{:ref, :name}`. See the [code interface guide](/documentation/topics/code-interface.md) for more. |





### Introspection

Target: `Ash.Resource.CalculationInterface`




### Introspection

Target: `Ash.Domain.Dsl.ResourceReference`




## execution
Options for how requests are executed using this domain



### Examples
```
execution do
  timeout :timer.seconds(30)
end

```




### Options

| Name | Type | Default | Docs |
|------|------|---------|------|
| [`timeout`](#execution-timeout){: #execution-timeout } | `timeout` | `30000` | The default timeout to use for requests using this domain. See the [timeouts guide](/documentation/topics/timeouts.md) for more. |
| [`trace_name`](#execution-trace_name){: #execution-trace_name } | `String.t` |  | The name to use in traces. Defaults to the last part of the module. See the [monitoring guide](/documentation/topics/monitoring.md) for more |






## authorization
Options for how requests are authorized using this domain. See the [Sensitive Data guide](/documentation/topics/security/sensitive-data.md) for more.




### Examples
```
authorization do
  authorize :always
end

```




### Options

| Name | Type | Default | Docs |
|------|------|---------|------|
| [`require_actor?`](#authorization-require_actor?){: #authorization-require_actor? } | `boolean` | `false` | Requires that an actor has been supplied. |
| [`authorize`](#authorization-authorize){: #authorization-authorize } | `:always \| :by_default \| :when_requested` | `:by_default` | When to run authorization for a given request. |







<style type="text/css">.spark-required::after { content: "*"; color: red !important; }</style>