{{$svrType := .ServiceType}}
{{$svrName := .ServiceName}}

{{- range .MethodSets}}
const Operation{{$svrType}}{{.OriginalName}} = "/{{$svrName}}/{{.OriginalName}}"
{{- end}}

type {{.ServiceType}}HTTPServer interface {
{{- range .MethodSets}}
{{- if ne .Comment ""}}
{{.Comment}}
{{- end}}
{{.Name}}(context.Context, *{{.Request}}) (*{{.Reply}}, error)
{{- end}}
}

func Register{{.ServiceType}}HTTPServer(s *transport.Server, srv {{.ServiceType}}HTTPServer) {
{{- range .Methods}}
s.AddMethod("{{.Method}}", "{{.Path}}", _{{$svrType}}_{{.Name}}{{.Num}}_HTTP_Handler(s, srv, Operation{{$svrType}}{{.OriginalName}}))
{{- end}}
}

{{range .Methods}}
func _{{$svrType}}_{{.Name}}{{.Num}}_HTTP_Handler(s *transport.Server, srv {{$svrType}}HTTPServer, operation string) func(ctx *gin.Context) {
return func(ctx *gin.Context) {
for _, f := range s.GetMiddlewares() {
if err := f(ctx, operation); err != nil {
s.ResultError(ctx, err)
return
}
}
var req {{.Request}}
{{- if .HasBody}}
if err := ctx.ShouldBindJSON(&req{{.Body}}); err != nil {
s.ResultError(ctx, err)
return
}
{{- end}}
if err := ctx.ShouldBindQuery(&req); err != nil {
s.ResultError(ctx, err)
return
}
{{- if .HasVars}}
if err := ctx.ShouldBindUri(&req); err != nil {
s.ResultError(ctx, err)
return
}
{{- end}}
if validate := reflect.ValueOf(&req).MethodByName("Validate"); validate.IsValid() {
if err := validate.Call(nil)[0].Interface(); err != nil {
s.ResultError(ctx, errors.New(400, "", "validate fail: " + err.(error).Error()))
return
}
}
reply, err := srv.{{.Name}}(ctx, &req)
if err != nil {
s.ResultError(ctx, err)
return
}
s.Result(ctx, 200, reply)
}
}
{{end}}
