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

func bindQueryWithSnakeCaseAlias(ctx *gin.Context, req interface{}) error {
	values := ctx.Request.URL.Query()
	if len(values) == 0 {
		return nil
	}

	normalized := make(url.Values, len(values))
	changed := false
	for k, vs := range values {
		copied := make([]string, len(vs))
		copy(copied, vs)
		normalized[k] = copied

		lowerCamel := snakeToLowerCamel(k)
		upperCamel := upperFirst(lowerCamel)
		if lowerCamel != "" && lowerCamel != k {
			if _, exists := normalized[lowerCamel]; !exists {
				normalized[lowerCamel] = copied
				changed = true
			}
		}
		if upperCamel != "" && upperCamel != k {
			if _, exists := normalized[upperCamel]; !exists {
				normalized[upperCamel] = copied
				changed = true
			}
		}
	}

	if changed {
		ctx.Request.URL.RawQuery = normalized.Encode()
	}
	return ctx.ShouldBindQuery(req)
}

func snakeToLowerCamel(s string) string {
	if s == "" {
		return s
	}
	b := make([]byte, 0, len(s))
	upperNext := false
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '_' {
			upperNext = true
			continue
		}
		if upperNext && c >= 'a' && c <= 'z' {
			c -= 'a' - 'A'
		}
		b = append(b, c)
		upperNext = false
	}
	if len(b) > 0 && b[0] >= 'A' && b[0] <= 'Z' {
		b[0] += 'a' - 'A'
	}
	return string(b)
}

func upperFirst(s string) string {
	if s == "" {
		return s
	}
	b := []byte(s)
	if b[0] >= 'a' && b[0] <= 'z' {
		b[0] -= 'a' - 'A'
	}
	return string(b)
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
if err := bindQueryWithSnakeCaseAlias(ctx, &req); err != nil {
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
