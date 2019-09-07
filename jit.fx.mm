#import "jit.common.h"
#import "max.jit.mop.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <string>

#define USE_PLUGIN

#import "./jit.fx.mxo/Contents/Resources/Plugin.h"

class App {
    
    private:
    
        bool isUpdate = false;
        std::string uid = "FX";
    
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.cycling74.jit.fx"];
        double date = 0;
    
        void *dylib = nullptr;
        Plugin *plugin = nullptr;
    
    public:
    
    
        void name(const char *s) {
            this->uid = s;
            this->setup();
        }
    
        void setup() {
            
            NSString *fileName = [NSString stringWithFormat:@"%@/%s/%s.dylib",[bundle resourcePath],this->uid.c_str(),this->uid.c_str()];
            
            double tmp = 0;
            
            if([fileManager fileExistsAtPath:fileName]) {
                tmp = [[[fileManager attributesOfItemAtPath:fileName error:nil] objectForKey:NSFileModificationDate] timeIntervalSince1970];
            }
            
            if(this->isUpdate) {
                this->isUpdate = false;
                tmp = 0;
            }
            
            if(this->date!=tmp) {
                
                post("reload %s",[fileName UTF8String]);
                
                this->cleanup();
                this->dylib = (Plugin *)dlopen([fileName UTF8String],RTLD_LAZY);
                
                if(this->dylib) {
                    this->plugin = ((newPlugin *)dlsym(dylib,"newPlugin"))(&post);
                    if(this->plugin) {
                        this->date = tmp;
                    }
                }
            }
        }
    
        void cleanup() {
            if(this->dylib&&this->plugin) {
                ((deletePlugin *)dlsym(this->dylib,"deletePlugin"))(this->plugin);
                dlclose(this->dylib);
                this->dylib = nullptr;
                this->plugin = nullptr;
            }
        }
    
        App() {
            this->setup();
        }
    
        ~App() {
            this->cleanup();
        }
    
        void set(t_symbol *s, t_atom *av) {
            
            if(this->dylib&&this->plugin) {
                this->plugin->set(s->s_name,jit_atom_getfloat(av));
            }
        }
    
        void calc(long *dim,t_jit_matrix_info *src_minfo, char *bip, t_jit_matrix_info *dst_minfo, char *bop) {
            
            if(this->dylib&&this->plugin) {
                this->setup();
                this->plugin->calc(dim,(uchar *)bip,src_minfo->dimstride[1],(uchar *)bop,dst_minfo->dimstride[1]);
            }
            else {
                
                long width  = dim[0];
                long height = dim[1];
                
                for(long i=0;i<height;i++) {
                    
                    uchar *src = (uchar *)(bip+i*src_minfo->dimstride[1]);
                    uchar *dst = (uchar *)(bop+i*dst_minfo->dimstride[1]);
                    
                    for(long j=0; j<width; j++) {
                        
                        *dst++ = *src++;
                        *dst++ = *src++;
                        *dst++ = *src++;
                        *dst++ = *src++;
                        
                    }
                }
            }
        }
};

typedef struct _jit_fx {
    t_object    ob;
    t_symbol    *name;
    App         *app;
} t_jit_fx;

typedef struct _max_jit_fx {
    t_object    ob;
    void        *obex;
} t_max_jit_fx;

extern "C" {
    void *_jit_fx_class = nullptr;
    void *_max_jit_fx_class = nullptr;

    t_jit_err jit_fx_init();
    t_jit_fx *jit_fx_new();
    void jit_fx_free(t_jit_fx *x);
    t_jit_err jit_fx_matrix_calc(t_jit_fx *x,void *inputs,void *outputs);
    t_jit_err jit_fx_init();
    void *max_jit_fx_new(t_symbol *s,long argc,t_atom *argv);
    void max_jit_fx_free(t_max_jit_fx *x);
}

inline void jit_fx_param_set(t_jit_fx *x, t_symbol *s, short ac, t_atom *av) {
    t_symbol *n=jit_atom_getsym(av++);
    if(x->app) x->app->set(n,av);
}

t_jit_err jit_fx_name(t_jit_fx *x, void *attr, long argc, t_atom *argv) {
    if (argc&&argv) {
        x->name = jit_atom_getsym(argv);
        if(x->app) x->app->name(x->name->s_name);
    }
    return JIT_ERR_NONE;
}

t_jit_err jit_fx_init() {
        
    _jit_fx_class = (void *)jit_class_new((char *)"jit_fx",(method)jit_fx_new,(method)jit_fx_free,sizeof(t_jit_fx),0L);
    t_jit_object *mop = (t_jit_object *)jit_object_new(_jit_sym_jit_mop,1,1);
    
    jit_mop_single_type(mop,_jit_sym_char);
    jit_mop_single_planecount(mop,4);
    jit_class_addadornment(_jit_fx_class,mop);
    
    jit_class_addmethod(_jit_fx_class,(method)jit_fx_matrix_calc,(char *)"matrix_calc",A_CANT,0L);
    
    long attrflags = JIT_ATTR_GET_DEFER_LOW|JIT_ATTR_SET_USURP_LOW;
    t_jit_object *attr = (t_jit_object *)jit_object_new(_jit_sym_jit_attr_offset,"plug-in",_jit_sym_symbol,attrflags,
                   (method)0L,(method)jit_fx_name,calcoffset(t_jit_fx,name));
    jit_class_addattr(_jit_fx_class,attr);
    object_addattr_parse(attr,"label",_jit_sym_symbol,0,"plug-in");
    
    jit_class_addmethod(_jit_fx_class,(method)jit_fx_param_set,"param.set",A_USURP_LOW,0L);
    jit_class_register(_jit_fx_class);
    
    return JIT_ERR_NONE;
}

t_jit_err jit_fx_matrix_calc(t_jit_fx *x, void *inputs, void *outputs) {
    t_jit_err err=JIT_ERR_NONE;
    long in_savelock,out_savelock;
    long dim[JIT_MATRIX_MAX_DIMCOUNT];
    void *in_matrix  = jit_object_method(inputs, _jit_sym_getindex,0);
    void *out_matrix = jit_object_method(outputs,_jit_sym_getindex,0);

    if(x&&in_matrix&&out_matrix) {
        t_jit_matrix_info in_minfo,out_minfo;
        char *in_bp,*out_bp;
        in_savelock  = (long) jit_object_method(in_matrix,_jit_sym_lock,1);
        out_savelock = (long) jit_object_method(out_matrix,_jit_sym_lock,1);
        jit_object_method(in_matrix,_jit_sym_getinfo,&in_minfo);
        jit_object_method(out_matrix,_jit_sym_getinfo,&out_minfo);
        jit_object_method(in_matrix,_jit_sym_getdata,&in_bp);
        jit_object_method(out_matrix,_jit_sym_getdata,&out_bp);
        if(!in_bp)  { err=JIT_ERR_INVALID_INPUT;  goto out;}
        if(!out_bp) { err=JIT_ERR_INVALID_OUTPUT; goto out;}
        if((in_minfo.type!=_jit_sym_char)||(in_minfo.type!=out_minfo.type)) {
            err=JIT_ERR_MISMATCH_TYPE;
            goto out;
        }
        if((in_minfo.planecount!=4)||(out_minfo.planecount!=4)) {
            err=JIT_ERR_MISMATCH_PLANE;
            goto out;
        }
        long dimcount   = out_minfo.dimcount;
        long planecount = out_minfo.planecount;
        for(int i=0;i<dimcount;i++) {
            dim[i] = MIN(in_minfo.dim[i],out_minfo.dim[i]);
        }
        if(dimcount!=2&&planecount!=4) return JIT_ERR_INVALID_PTR;
        
        x->app->calc(dim,&in_minfo,in_bp,&out_minfo,out_bp);
    
    }
    else {
        return JIT_ERR_INVALID_PTR;
    }
    
out:
    
    jit_object_method(out_matrix,_jit_sym_lock,out_savelock);
    jit_object_method(in_matrix,_jit_sym_lock,in_savelock);
    return err;
}

t_jit_fx *jit_fx_new() {
    t_jit_fx *x = (t_jit_fx *)jit_object_alloc(_jit_fx_class);
    x->app = new App();
    return x;
}

void jit_fx_free(t_jit_fx *x) {
     delete x->app;
}

extern "C" void ext_main(void *r) {

    jit_fx_init();

    t_class *max_class = class_new("jit.fx",(method)max_jit_fx_new,(method)max_jit_fx_free, sizeof(t_max_jit_fx),NULL,A_GIMME,0);
        
    max_jit_class_obex_setup(max_class,calcoffset(t_max_jit_fx,obex));
    maxclass *jit_class = (maxclass*)jit_class_findbyname(gensym("jit_fx"));
    max_jit_class_mop_wrap(max_class,jit_class,0);
    max_jit_class_wrap_standard(max_class,jit_class,0);
    class_addmethod(max_class,(method)max_jit_mop_assist,"assist",A_CANT,0);
    class_register(CLASS_BOX,(maxclass*)_max_jit_fx_class);
    _max_jit_fx_class = max_class;
    
}

void max_jit_fx_free(t_max_jit_fx *x) {
    max_jit_mop_free(x);
    jit_object_free(max_jit_obex_jitob_get(x));
    max_jit_object_free(x);
}

void *max_jit_fx_new(t_symbol *s, long argc, t_atom *argv) {
        
    void *x = max_jit_object_alloc((maxclass*)_max_jit_fx_class,gensym("jit_fx"));
    if(x) {
    
        void *o = jit_object_new(gensym("jit_fx"));
        if(o) {
            max_jit_mop_setup_simple(x,o,argc,argv);
            max_jit_attr_args(x,argc,argv);
        }
        else {
            jit_object_error((t_object *)x,(char *)"jit.fx: could not allocate object");
            freeobject((t_object *)x);
            x = nullptr;
        }
    }
    return x;
}
