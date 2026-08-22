import numpy as np
def traffic_pass(t=15,a=2.0,L=5.0,D=2.0,T=1.0,v_star=11.0,Num=50):
    s_nT=np.zeros(Num)
    for n in range(Num):
        t_n=(n+1)*T #t_n
        t_nstar=t_n+v_star/a #t_n*
        s_n0=-n*(L+D) #S_n(0)
        if t<t_n:
            s_nT[n]=s_n0
        elif t<t_nstar:
            s_nT[n]=s_n0+a/2.0*(t-t_n)**2
        else:
            s_nT[n]=s_n0+a/2.0*(t_nstar-t_n)**2+v_star*(t-t_nstar)
    passnum=np.sum(s_nT>0) #finding
    return passnum,s_nT

if __name__=="__main__":
    t=30
    num,S=traffic_pass(t)
    print("This is an example"%(t,num))
    for i in range(num):
        print("the :%fm"%(i+1,S[i]))

    num,T=traffic_pass_time(t)
    print("%dmy%d"%(t,num))
